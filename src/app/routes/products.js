import express from "express"
import { body, validationResult } from "express-validator"
import db from "../config/database.js"
import auth from "../middlewares/auth.js"

const router = express.Router()

// Get all products with advanced filtering - সব প্রোডাক্ট পাওয়া (ফিল্টারিং সহ)
router.get("/", async (req, res) => {
    try {
        const { category, minPrice, maxPrice, search, sortBy = "name", sortOrder = "ASC", page = 1, limit = 10 } = req.query

        let query = `
      SELECT 
        p.id, p.name, p.description, p.price, p.stock_quantity, p.image_url,
        c.name as category_name,
        COALESCE(AVG(r.rating), 0) as average_rating,
        COUNT(r.id) as review_count
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      LEFT JOIN reviews r ON p.id = r.product_id
      WHERE 1=1
    `

        const params = []

        // Search functionality - সার্চ ফাংশনালিটি
        if (search) {
            query += " AND (p.name LIKE ? OR p.description LIKE ?)"
            params.push(`%${search}%`, `%${search}%`)
        }

        // Category filter - ক্যাটেগরি ফিল্টার
        if (category) {
            query += " AND c.name = ?"
            params.push(category)
        }

        // Price range filter - দাম রেঞ্জ ফিল্টার
        if (minPrice) {
            query += " AND p.price >= ?"
            params.push(minPrice)
        }
        if (maxPrice) {
            query += " AND p.price <= ?"
            params.push(maxPrice)
        }

        query += " GROUP BY p.id, p.name, p.description, p.price, p.stock_quantity, p.image_url, c.name"

        // Sorting - সর্টিং
        const validSortFields = ["name", "price", "created_at", "average_rating"]
        const sortField = validSortFields.includes(sortBy) ? sortBy : "name"
        const order = sortOrder.toUpperCase() === "DESC" ? "DESC" : "ASC"

        if (sortBy === "average_rating") {
            query += ` ORDER BY average_rating ${order}`
        } else {
            query += ` ORDER BY p.${sortField} ${order}`
        }

        // Pagination - পেজিনেশন
        const offset = (page - 1) * limit
        query += " LIMIT ? OFFSET ?"
        params.push(Number.parseInt(limit), Number.parseInt(offset))

        const [products] = await db.execute(query, params)

        // Get total count for pagination - পেজিনেশনের জন্য টোটাল কাউন্ট
        let countQuery =
            "SELECT COUNT(DISTINCT p.id) as total FROM products p LEFT JOIN categories c ON p.category_id = c.id WHERE 1=1"
        const countParams = []

        if (search) {
            countQuery += " AND (p.name LIKE ? OR p.description LIKE ?)"
            countParams.push(`%${search}%`, `%${search}%`)
        }
        if (category) {
            countQuery += " AND c.name = ?"
            countParams.push(category)
        }
        if (minPrice) {
            countQuery += " AND p.price >= ?"
            countParams.push(minPrice)
        }
        if (maxPrice) {
            countQuery += " AND p.price <= ?"
            countParams.push(maxPrice)
        }

        const [countResult] = await db.execute(countQuery, countParams)
        const totalProducts = countResult[0].total

        res.json({
            products,
            pagination: {
                currentPage: Number.parseInt(page),
                totalPages: Math.ceil(totalProducts / limit),
                totalProducts,
                hasNext: page * limit < totalProducts,
                hasPrev: page > 1,
            },
        })
    } catch (error) {
        console.error("Get products error:", error)
        res.status(500).json({ message: "Server error while fetching products" })
    }
})

// Get single product with reviews - একটি প্রোডাক্ট পাওয়া (রিভিউ সহ)
router.get("/:id", async (req, res) => {
    try {
        const productId = req.params.id

        // Get product details with category - প্রোডাক্ট ডিটেইলস পাওয়া
        const [products] = await db.execute(
            `
      SELECT 
        p.*, 
        c.name as category_name,
        COALESCE(AVG(r.rating), 0) as average_rating,
        COUNT(r.id) as review_count
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      LEFT JOIN reviews r ON p.id = r.product_id
      WHERE p.id = ?
      GROUP BY p.id
    `,
            [productId],
        )

        if (products.length === 0) {
            return res.status(404).json({ message: "Product not found" })
        }

        // Get product reviews - প্রোডাক্ট রিভিউ পাওয়া
        const [reviews] = await db.execute(
            `
      SELECT 
        r.id, r.rating, r.comment, r.created_at,
        u.name as user_name
      FROM reviews r
      JOIN users u ON r.user_id = u.id
      WHERE r.product_id = ?
      ORDER BY r.created_at DESC
    `,
            [productId],
        )

        res.json({
            product: products[0],
            reviews,
        })
    } catch (error) {
        console.error("Get product error:", error)
        res.status(500).json({ message: "Server error while fetching product" })
    }
})

// Create new product (Admin only) - নতুন প্রোডাক্ট তৈরি করা (শুধু Admin)
router.post(
    "/",
    auth.authenticateToken,
    auth.requireAdmin,
    [
        body("name").notEmpty().withMessage("Product name is required"),
        body("price").isFloat({ min: 0 }).withMessage("Price must be a positive number"),
        body("stock_quantity").isInt({ min: 0 }).withMessage("Stock quantity must be a non-negative integer"),
        body("category_id").isInt().withMessage("Category ID must be an integer"),
    ],
    async (req, res) => {
        try {
            const errors = validationResult(req)
            if (!errors.isEmpty()) {
                return res.status(400).json({ errors: errors.array() })
            }

            const { name, description, price, stock_quantity, category_id, image_url } = req.body

            // Check if category exists - ক্যাটেগরি আছে কিনা চেক করা
            const [categories] = await db.execute("SELECT id FROM categories WHERE id = ?", [category_id])
            if (categories.length === 0) {
                return res.status(400).json({ message: "Invalid category ID" })
            }

            // Insert new product - নতুন প্রোডাক্ট ইনসার্ট করা
            const [result] = await db.execute(
                "INSERT INTO products (name, description, price, stock_quantity, category_id, image_url) VALUES (?, ?, ?, ?, ?, ?)",
                [name, description, price, stock_quantity, category_id, image_url],
            )

            // Get the created product - তৈরি হওয়া প্রোডাক্ট পাওয়া
            const [newProduct] = await db.execute(
                `
      SELECT p.*, c.name as category_name 
      FROM products p 
      LEFT JOIN categories c ON p.category_id = c.id 
      WHERE p.id = ?
    `,
                [result.insertId],
            )

            res.status(201).json({
                message: "Product created successfully",
                product: newProduct[0],
            })
        } catch (error) {
            console.error("Create product error:", error)
            res.status(500).json({ message: "Server error while creating product" })
        }
    },
)

// Update product (Admin only) - প্রোডাক্ট আপডেট করা (শুধু Admin)
router.put(
    "/:id",
    auth.authenticateToken,
    auth.requireAdmin,
    [
        body("name").optional().notEmpty().withMessage("Product name cannot be empty"),
        body("price").optional().isFloat({ min: 0 }).withMessage("Price must be a positive number"),
        body("stock_quantity").optional().isInt({ min: 0 }).withMessage("Stock quantity must be a non-negative integer"),
        body("category_id").optional().isInt().withMessage("Category ID must be an integer"),
    ],
    async (req, res) => {
        try {
            const errors = validationResult(req)
            if (!errors.isEmpty()) {
                return res.status(400).json({ errors: errors.array() })
            }

            const productId = req.params.id
            const { name, description, price, stock_quantity, category_id, image_url } = req.body

            // Check if product exists - প্রোডাক্ট আছে কিনা চেক করা
            const [existingProducts] = await db.execute("SELECT id FROM products WHERE id = ?", [productId])
            if (existingProducts.length === 0) {
                return res.status(404).json({ message: "Product not found" })
            }

            // Check category if provided - ক্যাটেগরি চেক করা (যদি দেওয়া হয়)
            if (category_id) {
                const [categories] = await db.execute("SELECT id FROM categories WHERE id = ?", [category_id])
                if (categories.length === 0) {
                    return res.status(400).json({ message: "Invalid category ID" })
                }
            }

            // Build dynamic update query - ডাইনামিক আপডেট কুয়েরি তৈরি করা
            const updateFields = []
            const updateValues = []

            if (name !== undefined) {
                updateFields.push("name = ?")
                updateValues.push(name)
            }
            if (description !== undefined) {
                updateFields.push("description = ?")
                updateValues.push(description)
            }
            if (price !== undefined) {
                updateFields.push("price = ?")
                updateValues.push(price)
            }
            if (stock_quantity !== undefined) {
                updateFields.push("stock_quantity = ?")
                updateValues.push(stock_quantity)
            }
            if (category_id !== undefined) {
                updateFields.push("category_id = ?")
                updateValues.push(category_id)
            }
            if (image_url !== undefined) {
                updateFields.push("image_url = ?")
                updateValues.push(image_url)
            }

            if (updateFields.length === 0) {
                return res.status(400).json({ message: "No fields to update" })
            }

            updateValues.push(productId)

            // Update product - প্রোডাক্ট আপডেট করা
            await db.execute(`UPDATE products SET ${updateFields.join(", ")} WHERE id = ?`, updateValues)

            // Get updated product - আপডেট হওয়া প্রোডাক্ট পাওয়া
            const [updatedProduct] = await db.execute(
                `
      SELECT p.*, c.name as category_name 
      FROM products p 
      LEFT JOIN categories c ON p.category_id = c.id 
      WHERE p.id = ?
    `,
                [productId],
            )

            res.json({
                message: "Product updated successfully",
                product: updatedProduct[0],
            })
        } catch (error) {
            console.error("Update product error:", error)
            res.status(500).json({ message: "Server error while updating product" })
        }
    },
)

// Delete product (Admin only) - প্রোডাক্ট ডিলিট করা (শুধু Admin)
router.delete("/:id", auth.authenticateToken, auth.requireAdmin, async (req, res) => {
    try {
        const productId = req.params.id

        // Check if product exists - প্রোডাক্ট আছে কিনা চেক করা
        const [existingProducts] = await db.execute("SELECT id, name FROM products WHERE id = ?", [productId])
        if (existingProducts.length === 0) {
            return res.status(404).json({ message: "Product not found" })
        }

        // Check if product is in any orders - প্রোডাক্ট কোনো অর্ডারে আছে কিনা চেক করা
        const [orderItems] = await db.execute("SELECT id FROM order_items WHERE product_id = ?", [productId])
        if (orderItems.length > 0) {
            return res.status(400).json({
                message: "Cannot delete product that has been ordered. Consider marking it as out of stock instead.",
            })
        }

        // Delete product - প্রোডাক্ট ডিলিট করা
        await db.execute("DELETE FROM products WHERE id = ?", [productId])

        res.json({
            message: "Product deleted successfully",
            deletedProduct: existingProducts[0],
        })
    } catch (error) {
        console.error("Delete product error:", error)
        res.status(500).json({ message: "Server error while deleting product" })
    }
})

// Get top selling products (Admin only) - টপ সেলিং প্রোডাক্ট পাওয়া (শুধু Admin)
router.get("/admin/top-selling", auth.authenticateToken, auth.requireAdmin, async (req, res) => {
    try {
        const limit = req.query.limit || 10

        // Call stored procedure - স্টোরড প্রসিডিউর কল করা
        const [results] = await db.execute("CALL GetTopSellingProducts(?)", [Number.parseInt(limit)])

        res.json({
            message: "Top selling products retrieved successfully",
            products: results[0],
        })
    } catch (error) {
        console.error("Get top selling products error:", error)
        res.status(500).json({ message: "Server error while fetching top selling products" })
    }
})

const productRoutes = router;
export default productRoutes;
