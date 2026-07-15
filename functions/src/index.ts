import {setGlobalOptions} from "firebase-functions/v2";

// Set global options for functions.
setGlobalOptions({maxInstances: 10});

// Export functions from results.ts.
export * from "./results";
export * from "./users";
