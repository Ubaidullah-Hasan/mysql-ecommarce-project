// import mysql from "mysql2"
// import config from "./index.js"

// // Database connection pool - ডাটাবেস কানেকশন পুল
// const pool = mysql.createPool({
//     host: config.db_host,
//     user: config.db_user,
//     password: config.db_password,
//     database: config.db_name,
//     waitForConnections: true,
//     connectionLimit: 10,
//     queueLimit: 0,
// })

// // Promise wrapper for easier async/await usage
// const promisePool = pool.promise()
// export default promisePool;




import mysql from "mysql2";
import config from "./index.js";
import fs from "fs";
import path from "path";

// Create a basic connection for initialization (not pool)
const tempConnection = mysql.createConnection({
    host: config.db_host,
    user: config.db_user,
    password: config.db_password,
    multipleStatements: true // Allow multiple SQL statements
});

const tempPromiseConnection = tempConnection.promise();

// Create the main connection pool
const pool = mysql.createPool({
    host: config.db_host,
    user: config.db_user,
    password: config.db_password,
    database: config.db_name, // Specify database here
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0,
    multipleStatements: true
});

const promisePool = pool.promise();

async function initializeDatabase() {
    try {
        // 1. Create database if not exists
        await tempPromiseConnection.execute(
            `CREATE DATABASE IF NOT EXISTS ${config.db_name}`
        );

        // ✅ সরাসরি query() দিয়ে USE করো
        await tempPromiseConnection.query(`USE ${config.db_name}`);

        // 2. Execute schema file
        const schemaPath = path.join(process.cwd(), 'src', 'app', 'database', 'schema.sql');
        const schemaSQL = fs.readFileSync(schemaPath, 'utf8');
        await tempPromiseConnection.query(schemaSQL.replace(/USE .*;?/g, '')); // Remove any USE statements

        // 3. Execute advanced features
        const advancedPath = path.join(process.cwd(), 'src', 'app', 'database', 'advanced_features.sql');
        const advancedSQL = fs.readFileSync(advancedPath, 'utf8');
        await tempPromiseConnection.query(advancedSQL.replace(/USE .*;?/g, ''));

        console.log("Database initialized successfully");
    } catch (error) {
        console.error("Database initialization error:", error);
        throw error;
    } finally {
        // Close the temporary connection
        await tempPromiseConnection.end();
    }
}

// Initialize database before exporting pool
initializeDatabase().catch(err => {
    console.error("Failed to initialize database:", err);
    process.exit(1);
});

export default promisePool;
