// Import the express module
import express from "express";

// Create an instance of express
const app = express();

// Define a route handler for the default home page
app.get("/", (req, res) => {
    // Send a response to the client
    res.send("Hello World!");
});

// Start the server and listen on port 3000
app.listen(3000, () => {
    // Log a message to the console once the server is running
    console.log("Server is running on port 3000");
});
