import express from "express"
import bcrypt from "bcryptjs"
import jwt from "jsonwebtoken"
import { body, validationResult } from "express-validator"
import db from "../config/database.js"

const router = express.Router()

// User Registration - ইউজার রেজিস্ট্রেশন
router.post(
    "/register",
    [
        body("name").notEmpty().withMessage("Name is required"),
        body("email").isEmail().withMessage("Valid email is required"),
        body("password").isLength({ min: 6 }).withMessage("Password must be at least 6 characters"),
        body("phone").optional().isMobilePhone(),
        body("address").optional(),
    ],
    async (req, res) => {
        try {
            const errors = validationResult(req)
            if (!errors.isEmpty()) {
                return res.status(400).json({ errors: errors.array() })
            }

            const { name, email, password, phone, address, role = "customer" } = req.body;


            // Check if user already exists - ইউজার আগে থেকে আছে কিনা চেক করা
            const [existingUsers] = await db.execute("SELECT id FROM users WHERE email = ?", [email])

            if (existingUsers.length > 0) {
                return res.status(400).json({ message: "User already exists with this email" })
            }

            // Hash password - পাসওয়ার্ড হ্যাশ করা
            const hashedPassword = await bcrypt.hash(password, 10)

            // Insert new user - নতুন ইউজার ইনসার্ট করা
            const [result] = await db.execute(
                "INSERT INTO users (name, email, password, role, phone, address) VALUES (?, ?, ?, ?, ?, ?)",
                [name, email, hashedPassword, role, phone, address],
            )

            // Generate JWT token
            const token = jwt.sign({ userId: result.insertId, email, role }, process.env.JWT_SECRET, { expiresIn: "24h" })

            res.status(201).json({
                message: "User registered successfully",
                token,
                user: {
                    id: result.insertId,
                    name,
                    email,
                    role,
                },
            })
        } catch (error) {
            console.error("Registration error:", error)
            res.status(500).json({ message: "Server error during registration" })
        }
    },
)

// User Login - ইউজার লগইন
router.post(
    "/login",
    [
        body("email").isEmail().withMessage("Valid email is required"),
        body("password").notEmpty().withMessage("Password is required"),
    ],
    async (req, res) => {
        try {
            const errors = validationResult(req)
            if (!errors.isEmpty()) {
                return res.status(400).json({ errors: errors.array() })
            }

            const { email, password } = req.body

            // Find user by email - ইমেইল দিয়ে ইউজার খোঁজা
            const [users] = await db.execute("SELECT id, name, email, password, role FROM users WHERE email = ?", [email])

            if (users.length === 0) {
                return res.status(401).json({ message: "Invalid email or password" })
            }

            const user = users[0]

            // Verify password - পাসওয়ার্ড ভেরিফাই করা
            const isPasswordValid = await bcrypt.compare(password, user.password)
            if (!isPasswordValid) {
                return res.status(401).json({ message: "Invalid email or password" })
            }

            // Generate JWT token
            const token = jwt.sign({ userId: user.id, email: user.email, role: user.role }, process.env.JWT_SECRET, {
                expiresIn: "24h",
            })

            res.json({
                message: "Login successful",
                token,
                user: {
                    id: user.id,
                    name: user.name,
                    email: user.email,
                    role: user.role,
                },
            })
        } catch (error) {
            console.error("Login error:", error)
            res.status(500).json({ message: "Server error during login" })
        }
    },
)

const authRoutes = router;
export default authRoutes;
