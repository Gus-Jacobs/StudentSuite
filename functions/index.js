const functions = require("firebase-functions");
const admin = require("firebase-admin");
const {GoogleGenerativeAI} = require("@google/generative-ai");
const {OpenAI} = require("openai");

// Initialize Firebase Admin SDK ONCE at the top level of your script.
admin.initializeApp();

// Your email address where you want to receive the feedback.
const ADMIN_EMAIL = "pegumaxinc@gmail.com";

/**
 * Creates a Stripe Checkout session with the user's email and redirects
 * them to the Stripe checkout page.
 */
exports.createStripeCheckout = functions.firestore
    .document("users/{userId}/checkout_sessions/{sessionId}")
    .onCreate(async (snap, context) => {
      const {price, success_url, cancel_url} = snap.data();
      const userId = context.params.userId;
      const stripe = require("stripe")(functions.config().stripe.secret);

      try {
        const user = await admin.auth().getUser(userId);
        const userDoc = await admin.firestore()
            .collection("users").doc(userId).get();

        let customerId = userDoc.data()?.stripeCustomerId;

        // If the user doesn't have a Stripe Customer ID, create one.
        if (!customerId) {
          const customer = await stripe.customers.create({
            email: user.email,
            metadata: {firebaseUID: userId},
          });
          customerId = customer.id;
          await admin.firestore().collection("users").doc(userId).update({
            stripeCustomerId: customerId,
          });
        }

        const session = await stripe.checkout.sessions.create({
          payment_method_types: ["card"],
          mode: "subscription",
          customer: customerId,
          line_items: [{price, quantity: 1}],
          success_url,
          cancel_url,
        });

        await snap.ref.set({url: session.url}, {merge: true});
      } catch (error) {
        console.error("Stripe Checkout Error:", error);
        await snap.ref.set({error: {message: error.message}}, {merge: true});
      }
    });

/**
 * Creates a Stripe Customer Portal session to allow users to manage their
 * subscriptions.
 */
exports.createStripePortalLink = functions.firestore
    .document("users/{userId}/portal_links/{linkId}")
    .onCreate(async (snap, context) => {
      const {return_url} = snap.data();
      const userId = context.params.userId;
      const stripe = require("stripe")(functions.config().stripe.secret);

      try {
        const userDoc = await admin.firestore()
            .collection("users").doc(userId).get();
        const customerId = userDoc.data()?.stripeCustomerId;

        if (!customerId) {
          throw new Error("User does not have a Stripe Customer ID.");
        }

        const session = await stripe.billingPortal.sessions.create({
          customer: customerId,
          return_url,
        });

        await snap.ref.set({url: session.url}, {merge: true});
      } catch (error) {
        console.error("Stripe Portal Error:", error);
        await snap.ref.set({error: {message: error.message}}, {merge: true});
      }
    });


/**
 * A webhook that listens for events from Stripe and updates the user's
 * role in Firestore accordingly.
 */
exports.stripeWebhook = functions.https.onRequest(async (req, res) => {
  const stripe = require("stripe")(functions.config().stripe.secret);
  const signature = req.headers["stripe-signature"];
  const endpointSecret = functions.config().stripe.webhook_secret;

  let event;

  try {
    event = stripe.webhooks.constructEvent(
        req.rawBody,
        signature,
        endpointSecret,
    );
  } catch (err) {
    console.error("Webhook signature verification failed.", err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  let subscription;
  let status;

  // Handle the event
  switch (event.type) {
    case "customer.subscription.updated":
      subscription = event.data.object;
      status = subscription.status;
      console.log(`Subscription status is ${status}.`);
      await updateUserRole(subscription.customer, status);
      break;
    case "customer.subscription.deleted":
      subscription = event.data.object;
      status = subscription.status;
      console.log(`Subscription status is ${status}.`);
      await updateUserRole(subscription.customer, status);
      break;
    case "checkout.session.completed":
      const session = event.data.object;
      if (session.mode === "subscription") {
        const customerId = session.customer;
        // The subscription is active immediately.
        const userRecord = await updateUserRole(customerId, "active");

        // --- Referral Logic ---
        // If we found the user and they were referred, give credit.
        if (userRecord) {
          const userData = userRecord.data();

          // Check if this user was referred and hasn't been credited for it yet
          if (userData.referredBy && !userData.referralCreditGiven) {
            const referrerId = userData.referredBy;
            const referrerDoc = await admin.firestore()
                .collection("users").doc(referrerId).get();

            if (referrerDoc.exists) {
              const referrerData = referrerDoc.data();
              const referrerStripeId = referrerData.stripeCustomerId;

              if (referrerStripeId) {
                try {
                  // Give $5 credit to the referrer
                  await stripe.customers.createBalanceTransaction(
                      referrerStripeId,
                      {
                        amount: -599, // -599 cents = -$5.99
                        currency: "usd",
                        description: `Referral credit for ${userData.email}`,
                      },
                  );
                  console.log(`Gave $5 credit to referrer ${referrerId} for referring ${userRecord.id}`);

                  // Mark that credit has been given to prevent duplicates
                  await userRecord.ref.update({referralCreditGiven: true});
                } catch (creditError) {
                  console.error(`Failed to give referral credit to ${referrerId}:`, creditError);
                }
              }
            }
          }
        }
        // --- End Referral Logic ---
      }
      break;
    default:
      console.log(`Unhandled event type ${event.type}`);
  }

  res.status(200).send();
});

/**
 * Updates the user's custom claim and Firestore document based on their
 * Stripe subscription status.
 * @param {string} stripeCustomerId The Stripe Customer ID.
 * @param {string} status The status of the Stripe subscription.
 */
async function updateUserRole(stripeCustomerId, status) {
  const usersQuery = await admin.firestore().collection("users")
      .where("stripeCustomerId", "==", stripeCustomerId).get();

  if (usersQuery.empty) {
    console.error(`No user found for Stripe Customer ID: ${stripeCustomerId}`);
    return null;
  }

  const userDoc = usersQuery.docs[0];
  const userId = userDoc.id;
  const role = status === "active" ? "pro" : "free";

  try {
    // Update Firestore document
    await userDoc.ref.update({stripeRole: role});

    // Update Firebase Auth custom claims (optional but good for security rules)
    await admin.auth().setCustomUserClaims(userId, {stripeRole: role});

    console.log(`Successfully set role to '${role}' for user ${userId}`);
    return userDoc; // Return the document for further processing
  } catch (error) {
    console.error("Failed to update user role:", error);
    return null;
  }
}

/**
 * Listens for new documents in the 'feedback' collection and sends an email.
 */
exports.sendFeedbackEmail = functions.firestore
    .document("feedback/{feedbackId}")
    .onCreate(async (snap, context) => {
      const nodemailer = require("nodemailer");
      // Lazily initialize mail transport inside the function to avoid deployment timeouts.
      const mailTransport = nodemailer.createTransport({
        service: "gmail",
        auth: {
          user: functions.config().gmail.email,
          pass: functions.config().gmail.password,
        },
      });

      const feedbackData = snap.data();

      const mailOptions = {
        from: `"Student Suite Feedback" <${functions.config().gmail.email}>`,
        to: ADMIN_EMAIL,
        subject: `New Feedback [${feedbackData.category}] from ${feedbackData.displayName}`,
        html: `
          <h1>New Feedback Received</h1>
          <p><b>From:</b> ${feedbackData.displayName} (${feedbackData.email})</p>
          <p><b>User ID:</b> ${feedbackData.userId}</p>
          <p><b>Category:</b> ${feedbackData.category}</p>
          <p><b>Platform:</b> ${feedbackData.platform}</p>
          <p><b>App Version:</b> ${feedbackData.version}</p>
          <hr>
          <h2>Message:</h2>
          <p>${feedbackData.message.replace(/\n/g, "<br>")}</p>
        `,
      };

      try {
        await mailTransport.sendMail(mailOptions);
        console.log("Feedback email sent successfully for:", context.params.feedbackId);
      } catch (error) {
        console.error("There was an error while sending the feedback email:", error);
      }
    });

/**
 * Cleans up user data from Firestore and Storage when a user is deleted from
 * Firebase Authentication.
 */
exports.onUserDeleted = functions.auth.user().onDelete(async (user) => {
  const userId = user.uid;
  console.log(`Starting cleanup for deleted user: ${userId}`);

  const firestore = admin.firestore();
  const storage = admin.storage().bucket();

  // 1. Recursively delete the user's document and all subcollections
  // (e.g., checkout_sessions, portal_links, aiUsage) from Firestore.
  const userDocRef = firestore.collection("users").doc(userId);
  try {
    await firestore.recursiveDelete(userDocRef);
    console.log(`Successfully deleted Firestore data for user: ${userId}`);
  } catch (error) {
    console.error(`Error deleting Firestore data for user ${userId}:`, error);
  }

  // 2. Delete the user's profile picture from Firebase Storage.
  const profilePicRef = storage.file(`profile_pics/${userId}`);
  try {
    await profilePicRef.delete();
    console.log(`Successfully deleted profile picture for user: ${userId}`);
  } catch (error) {
    // It's okay if the file doesn't exist (error code 404).
    if (error.code !== 404) {
      console.error(`Error deleting profile picture for user ${userId}:`, error);
    }
  }
});

/**
 * A callable function to validate a referral code securely on the server.
 * @param {object} data The data passed to the function.
 * @param {string} data.code The referral code to validate.
 * @returns {Promise<{referrerId: string|null}>} The UID of the referrer or null.
 */
exports.validateReferralCode = functions.https.onCall(async (data, context) => {
  const code = data.code;
  if (!code || typeof code !== "string" || code.length === 0) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "The function must be called with a 'code' argument.",
    );
  }

  const usersRef = admin.firestore().collection("users");
  const snapshot = await usersRef.where("uid_prefix", "==", code.toUpperCase()).limit(1).get();

  if (snapshot.empty) {
    return {referrerId: null};
  }

  return {referrerId: snapshot.docs[0].id};
});

/**
 * Sends a monthly report summarizing AI usage and user statistics.
 * This function is scheduled to run at 9:00 AM on the 1st day of every month.
 */
exports.monthlyReport = functions.pubsub.schedule("0 9 1 * *")
    .timeZone("America/New_York") // Set to your preferred timezone
    .onRun(async (context) => {
      const nodemailer = require("nodemailer");
      console.log("Generating monthly report...");

      const now = new Date();
      // Get the previous month (e.g., on July 1st, this will be June)
      const lastMonthDate = new Date(now.getFullYear(), now.getMonth() - 1, 1);
      const monthYear = `${lastMonthDate.getFullYear()}-${(lastMonthDate.getMonth() + 1).toString().padStart(2, "0")}`;

      const db = admin.firestore();
      const usersSnapshot = await db.collection("users").get();
      const totalUsers = usersSnapshot.size;
      let activeUsers = 0;
      let totalRequests = 0;
      let totalCost = 0;
      let totalInputTokens = 0;
      let totalOutputTokens = 0;

      for (const userDoc of usersSnapshot.docs) {
        const usageDoc = await db.collection("users").doc(userDoc.id).collection("aiUsage").doc(monthYear).get();
        if (usageDoc.exists) {
          const usageData = usageDoc.data();
          activeUsers++;
          totalRequests += usageData.requests || 0;
          totalCost += usageData.cost || 0;
          totalInputTokens += usageData.inputTokens || 0;
          totalOutputTokens += usageData.outputTokens || 0;
        }
      }

      const avgRequests = activeUsers > 0 ? (totalRequests / activeUsers).toFixed(2) : 0;
      const avgCost = activeUsers > 0 ? (totalCost / activeUsers).toFixed(2) : 0;

      const mailTransport = nodemailer.createTransport({
        service: "gmail",
        auth: {
          user: functions.config().gmail.email,
          pass: functions.config().gmail.password,
        },
      });

      const mailOptions = {
        from: `"Student Suite Reports" <${functions.config().gmail.email}>`,
        to: ADMIN_EMAIL,
        subject: `Student Suite Monthly Report for ${monthYear}`,
        html: `<h1>Student Suite Report: ${monthYear}</h1>
               <p><b>Total Users:</b> ${totalUsers}</p>
               <p><b>Active AI Users:</b> ${activeUsers}</p>
               <hr>
               <p><b>Total AI Requests:</b> ${totalRequests.toLocaleString()}</p>
               <p><b>Total AI Cost:</b> $${totalCost.toFixed(4)}</p>
               <p><b>Total Input Tokens:</b> ${totalInputTokens.toLocaleString()}</p>
               <p><b>Total Output Tokens:</b> ${totalOutputTokens.toLocaleString()}</p>
               <hr>
               <p><b>Average Requests per Active User:</b> ${avgRequests}</p>
               <p><b>Average Cost per Active User:</b> $${avgCost}</p>`,
      };

      try {
        await mailTransport.sendMail(mailOptions);
        console.log(`Monthly report for ${monthYear} sent successfully.`);
      } catch (error) {
        console.error("Error sending monthly report email:", error);
      }
    });

/**
 * A generic callable function to handle various AI generation tasks.
 * It implements a failover mechanism, trying multiple API keys.
 * Expects `data.prompt` to be provided.
 */
async function handleGeneration(data, context) {
  // Ensure app is initialized. This is a safeguard against cold start issues
  // where the global scope might not be fully available.
  if (admin.apps.length === 0) {
    admin.initializeApp();
  }

  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "The function must be called while authenticated.",
    );
  }

  const userId = context.auth.uid;

  // --- 1. Check Usage Limit ---
  const now = new Date();
  const monthYear = `${now.getFullYear()}-${(now.getMonth() + 1).toString().padStart(2, "0")}`;
  const usageDocRef = admin.firestore().collection("users").doc(userId).collection("aiUsage").doc(monthYear);
  const usageDoc = await usageDocRef.get();

  const monthlyCostLimit = 3.00; // $3.00 limit

  if (usageDoc.exists) {
    const currentCost = usageDoc.data().cost || 0;
    if (currentCost >= monthlyCostLimit) {
      throw new functions.https.HttpsError(
          "resource-exhausted",
          "You have reached your monthly AI usage limit. This will reset on the first of the next month.",
      );
    }
  }

  const prompt = data.prompt;
  if (!prompt || typeof prompt !== "string") {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "The function must be called with a 'prompt' argument.",
    );
  }

  // --- AI Configuration ---
  // This is defined inside the function to be lazily initialized.
  const GOOGLE_MODEL_NAME = "gemini-1.5-flash-latest";
  const OPENAI_MODEL_NAME = "gpt-4o-mini";

  const modelPricing = {
    [GOOGLE_MODEL_NAME]: {
      "input": 0.35 / 1000000, // $0.35 per 1M input tokens
      "output": 0.70 / 1000000, // $0.70 per 1M output tokens
    },
    [OPENAI_MODEL_NAME]: {
      "input": 0.15 / 1000000, // $0.15 per 1M input tokens
      "output": 0.60 / 1000000, // $0.60 per 1M output tokens
    },
  };

  // Get keys from config. Use || "" to avoid errors if a key is not set.
  const googleApiKey1 = functions.config().google?.api_key1 || "";
  const googleApiKey2 = functions.config().google?.api_key2 || "";
  const googleApiKey3 = functions.config().google?.api_key3 || "";
  const openAiApiKey = functions.config().openai?.api_key || "";

  // Create a list of API configurations in the desired failover order.
  // This list is now static and not shuffled.
  const apiConfigs = [
    {provider: "google", apiKey: googleApiKey3, model: GOOGLE_MODEL_NAME},
    {provider: "google", apiKey: googleApiKey2, model: GOOGLE_MODEL_NAME},
    {provider: "google", apiKey: googleApiKey1, model: GOOGLE_MODEL_NAME},
    {provider: "openai", apiKey: openAiApiKey, model: OPENAI_MODEL_NAME},
  ].filter((c) => c.apiKey);

  const errors = [];

  for (const config of apiConfigs) {
    console.log(
        `Attempting API call with ${config.provider} (${config.model}) using key ending in ...${config.apiKey.slice(-4)}`,
    );
    try {
      let responseText = "";
      let usage = {inputTokens: 0, outputTokens: 0};

      if (config.provider === "google") {
        const genAI = new GoogleGenerativeAI(config.apiKey);
        const model = genAI.getGenerativeModel({model: config.model});
        const result = await model.generateContent(prompt);
        const response = result.response;
        if (!response) {
          throw new Error("The model's response was empty or invalid.");
        }
        responseText = response.text();
        const usageMetadata = response.usageMetadata;
        if (usageMetadata) {
          usage.inputTokens = usageMetadata.promptTokenCount;
          usage.outputTokens = usageMetadata.candidatesTokenCount;
        }
      } else if (config.provider === "openai") {
        const openaiClient = new OpenAI({apiKey: config.apiKey});
        const completion = await openaiClient.chat.completions.create({
          messages: [{role: "user", content: prompt}],
          model: config.model,
        });
        responseText = completion.choices[0]?.message?.content ?? "";
        if (completion.usage) {
          usage.inputTokens = completion.usage.prompt_tokens;
          usage.outputTokens = completion.usage.completion_tokens;
        }
      }

      if (responseText.trim() === "") {
        throw new Error("Model returned an empty response.");
      }

      console.log(`✅ Success with ${config.provider} (${config.model}).`);

      // --- 2. Calculate and Record Cost ---
      const pricing = modelPricing[config.model];
      if (pricing) {
        const cost = (usage.inputTokens * pricing.input) + (usage.outputTokens * pricing.output);
        await usageDocRef.set({
          cost: admin.firestore.FieldValue.increment(cost),
          requests: admin.firestore.FieldValue.increment(1),
          inputTokens: admin.firestore.FieldValue.increment(usage.inputTokens),
          outputTokens: admin.firestore.FieldValue.increment(usage.outputTokens),
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
      }

      return {text: responseText};
    } catch (error) {
      const errorMessage = `🚨 API call with ${config.provider} (${config.model}) failed: ${error.message}`;
      console.error(errorMessage);
      errors.push(errorMessage);
    }
  }

  // If all APIs failed
  console.error("All API calls failed. Errors:", errors);
  throw new functions.https.HttpsError(
      "unavailable",
      "The AI service is currently unavailable after multiple attempts. Please try again later.",
  );
}

// Create specific endpoints for each AI feature for clarity and maintainability.
exports.generateStudyNote = functions.https.onCall(handleGeneration);
exports.generateFlashcards = functions.https.onCall(handleGeneration);
exports.generateResume = functions.https.onCall(handleGeneration);
exports.generateCoverLetter = functions.https.onCall(handleGeneration);
exports.getTeacherResponse = functions.https.onCall(handleGeneration);
exports.getInterviewerResponse = functions.https.onCall(handleGeneration);
exports.getInterviewFeedback = functions.https.onCall(handleGeneration);

/**
 * Sets the 'isFounder' flag for the first 1000 users upon creation.
 * This is triggered whenever a new document is created in the /users collection.
 */
exports.onUserCreate = functions.firestore
    .document("users/{userId}")
    .onCreate(async (snap, context) => {
      const db = admin.firestore();
      const metadataRef = db.collection("globals").doc("metadata");

      try {
        await db.runTransaction(async (transaction) => {
          const metadataDoc = await transaction.get(metadataRef);

          let userCount = 0;
          if (metadataDoc.exists) {
            userCount = metadataDoc.data().userCount || 0;
          }

          // Set the isFounder flag based on the current count
          const isFounder = userCount < 1000;
          transaction.update(snap.ref, { isFounder: isFounder });

          // Increment the global user counter
          transaction.set(metadataRef, { userCount: userCount + 1 }, { merge: true });
        });
        console.log(`User ${context.params.userId} processed. Founder status: ${userCount < 1000}`);
      } catch (e) {
        console.error("onUserCreate transaction failed: ", e);
      }
    });
