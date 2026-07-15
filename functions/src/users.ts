import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

// Ensure Firebase Admin is initialized.
if (admin.apps.length === 0) {
  admin.initializeApp();
}

/**
 * Creates a new Firebase Authentication user.
 * This function is callable from the client-side.
 *
 * @param {CallableRequest} request The request object from the client.
 * @param {string} request.data.email The new user's email.
 * @param {string} request.data.password The new user's password.
 * @param {string} request.data.displayName The new user's display name.
 *
 * @returns {Promise<{uid: string}>} A promise that resolves with the new
 * user's UID.
 * @throws {HttpsError} Throws an error if the request is not
 * authenticated or if the user creation fails.
 */
export const createUser = onCall(async (request) => {
  // TODO: Add logic to ensure only admins can call this function.
  // For example, check for a custom claim:
  // if (request.auth?.token.isAdmin !== true) {
  //   throw new HttpsError(
  //     "permission-denied",
  //     "Must be an administrative user to create users."
  //   );
  // }

  const {email, password, displayName} = request.data;

  if (!email || !password || !displayName) {
    throw new HttpsError(
      "invalid-argument",
      "The function must be called with 'email', 'password', and " +
        "'displayName' arguments."
    );
  }

  try {
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      displayName: displayName,
    });

    return {uid: userRecord.uid};
  } catch (error) {
    if (error instanceof Error) {
      throw new HttpsError("internal", error.message);
    }
    throw new HttpsError("internal", "An unknown error occurred.");
  }
});
