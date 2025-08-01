// const mysql = require("mysql2")
import mysql from "mysql2"
import config from "./index.js"

// Database connection pool - ডাটাবেস কানেকশন পুল
const pool = mysql.createPool({
    host: config.db_host,
    user: config.db_user,
    password: config.db_password,
    database: config.db_name,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0,
})

// Promise wrapper for easier async/await usage
const promisePool = pool.promise()

export default promisePool;