// Importing necessary modules
import express from "express";
import * as LaunchDarkly from '@launchdarkly/node-server-sdk'

// Initializing the Express application
const app = express();

// Setting up LaunchDarkly SDK key and feature flag key from environment variables or default values
const sdkKey = process.env.LAUNCHDARKLY_SDK_KEY ?? 'test-sdk-key';
const featureFlagKey = process.env.LAUNCHDARKLY_FLAG_KEY ?? 'test-feature-flag';

// Initializing LaunchDarkly client
const ldClient = LaunchDarkly.init(sdkKey);

let message;

// Function to initialize LaunchDarkly client
const initializeLaunchDarkly = async () => {
    try {
        // Waiting for LaunchDarkly client initialization with a timeout of 5 seconds
        await ldClient.waitForInitialization({timeout: 5});
        message = 'LaunchDarkly client initialized';
        console.log(message);
    } catch (err) {
        // Handling initialization failure
        message = 'LaunchDarkly client initialization failed or did not complete before timeout';
        console.error(message, err);
    }
};

// Call the initialization function
initializeLaunchDarkly();

// Setting up the root route
app.get("/", (req, res) => {
    res.send(`Hello World!<br/>Status = ${message}<p>Feature Flag: <a href="/feature-flag">/feature-flag</a></p>`);
});

// Setting up the feature flag route
app.get("/feature-flag", (req, res) => {
    ldClient.variation(featureFlagKey, { kind: 'user', key: 'user-key', anonymous: true }, false, (err, showFeature) => {
        if (err) {
            // Handling error in feature flag evaluation
            res.status(500).send('Error evaluating feature flag');
            console.error('Error evaluating feature flag', err);
            return;
        }
        if (showFeature) {
            res.send(`Feature is enabled<br/>Status = ${message}`);
            console.log('Feature is enabled');
        } else {
            res.send(`Feature is disabled<br/>Status = ${message}`);
            console.log('Feature is disabled');
        }
    });
});

// Starting the server on port 3000
app.listen(3000, () => {
    console.log("Server is running on port 3000");
});