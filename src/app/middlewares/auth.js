const jwt = require("jsonwebtoken")
const db = require("../config/database")

import jwt from "jsonwebtoken"
import db from "../config/db.js"

// JWT Token verify করার middleware
const authenticateToken = async (req, res, next) => {
    const authHeader = req.headers["authorization"]
    const token = authHeader && authHeader.split(" ")[1]

    if (!token) {
        return res.status(401).json({ message: "Access token required" })
    }

    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET)

        // Database থেকে user verify করা
        const [users] = await db.execute("SELECT id, name, email, role FROM users WHERE id = ?", [decoded.userId])

        if (users.length === 0) {
            return res.status(401).json({ message: "Invalid token" })
        }

        req.user = users[0]
        next()
    } catch (error) {
        return res.status(403).json({ message: "Invalid or expired token" })
    }
}

// Admin role check করার middleware
const requireAdmin = (req, res, next) => {
    if (req.user.role !== "admin") {
        return res.status(403).json({ message: "Admin access required" })
    }
    next()
}

// Customer role check করার middleware
const requireCustomer = (req, res, next) => {
    if (req.user.role !== "customer") {
        return res.status(403).json({ message: "Customer access required" })
    }
    next()
}

module.exports = {
    authenticateToken,
    requireAdmin,
    requireCustomer,
}
