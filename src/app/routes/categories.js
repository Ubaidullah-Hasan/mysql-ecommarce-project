import express from "express"
import { body, validationResult } from "express-validator"
import db from "../config/database.js"
import auth from "../middlewares/auth.js"

const router = express.Router()

// Middleware to ensure categories table exists
const ensureCategoriesTable = async (req, res, next) => {
    try {
        await db.execute(`
            CREATE TABLE IF NOT EXISTS categories (
                id INT AUTO_INCREMENT PRIMARY KEY,
                name VARCHAR(255) NOT NULL UNIQUE,
                description TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )
        `);
        next();
    } catch (error) {
        console.error("Categories table creation error:", error);
        res.status(500).json({ message: "Database initialization failed" });
    }
};

// Get all categories - সব ক্যাটেগরি পাওয়া
router.get("/", async (req, res) => {
    try {
        // Get categories with product count - প্রোডাক্ট কাউন্ট সহ ক্যাটেগরি পাওয়া
        const [categories] = await db.execute(`
      SELECT 
        c.id, c.name, c.description, c.created_at,
        COUNT(p.id) as product_count
      FROM categories c
      LEFT JOIN products p ON c.id = p.category_id
      GROUP BY c.id, c.name, c.description, c.created_at
      ORDER BY c.name
    `)

        res.json({
            categories,
        })
    } catch (error) {
        console.error("Get categories error:", error)
        res.status(500).json({ message: "Server error while fetching categories" })
    }
})

// Create new category (Admin only) - নতুন ক্যাটেগরি তৈরি করা (শুধু Admin)
router.post(
    "/",
    auth.authenticateToken,
    auth.requireAdmin,
    ensureCategoriesTable,
    [body("name").notEmpty().withMessage("Category name is required"), body("description").optional()],
    async (req, res) => {
        try {
            const errors = validationResult(req)
            if (!errors.isEmpty()) {
                return res.status(400).json({ errors: errors.array() })
            }

            const { name, description } = req.body

            // Check if category already exists - ক্যাটেগরি আগে থেকে আছে কিনা চেক করা
            const [existingCategories] = await db.execute("SELECT id FROM categories WHERE name = ?", [name])

            if (existingCategories.length > 0) {
                return res.status(400).json({ message: "Category with this name already exists" })
            }

            // Insert new category - নতুন ক্যাটেগরি ইনসার্ট করা
            const [result] = await db.execute("INSERT INTO categories (name, description) VALUES (?, ?)", [name, description])

            res.status(201).json({
                message: "Category created successfully",
                category: {
                    id: result.insertId,
                    name,
                    description,
                },
            })
        } catch (error) {
            console.error("Create category error:", error)
            res.status(500).json({ message: "Server error while creating category" })
        }
    },
)

const categoryRoutes = router;

export default categoryRoutes;
