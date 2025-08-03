import express from "express"
import { body, validationResult } from "express-validator"
import db from "../config/database.js"
import auth from "../middlewares/auth.js"

const router = express.Router()

// Place order - অর্ডার প্লেস করা
router.post(
    "/place",
    auth.authenticateToken,
    auth.requireCustomer,
    [body("shipping_address").notEmpty().withMessage("Shipping address is required")],
    async (req, res) => {
        try {
            const errors = validationResult(req)
            if (!errors.isEmpty()) {
                return res.status(400).json({ errors: errors.array() })
            }

            const userId = req.user.id
            const { shipping_address } = req.body

            // Call stored procedure to place order - অর্ডার প্লেস করার জন্য স্টোরড প্রসিডিউর কল করা
            const [results] = await db.execute("CALL PlaceOrder(?, ?)", [userId, shipping_address])

            const orderResult = results[0][0]

            res.status(201).json({
                message: "Order placed successfully",
                order: {
                    id: orderResult.order_id,
                    total_amount: orderResult.total_amount,
                    status: "pending",
                    shipping_address,
                },
            })
        } catch (error) {
            console.error("Place order error:", error)

            if (error.message.includes("Cart is empty")) {
                return res.status(400).json({ message: "Your cart is empty" })
            }
            if (error.message.includes("Insufficient stock")) {
                return res.status(400).json({ message: "Some items in your cart are out of stock" })
            }

            res.status(500).json({ message: "Server error while placing order" })
        }
    },
)

// Get user's orders - ইউজারের অর্ডার পাওয়া
router.get("/my-orders", auth.authenticateToken, auth.requireCustomer, async (req, res) => {
    try {
        const userId = req.user.id
        const { status, page = 1, limit = 10 } = req.query

        let query = `
      SELECT 
        o.id, o.total_amount, o.status, o.shipping_address, o.created_at,
        COUNT(oi.id) as total_items
      FROM orders o
      LEFT JOIN order_items oi ON o.id = oi.order_id
      WHERE o.user_id = ?
    `

        const params = [userId]

        // Filter by status if provided - স্ট্যাটাস দিয়ে ফিল্টার করা
        if (status) {
            query += " AND o.status = ?"
            params.push(status)
        }

        query += " GROUP BY o.id ORDER BY o.created_at DESC"

        // Pagination - পেজিনেশন
        const offset = (page - 1) * limit
        query += " LIMIT ? OFFSET ?"
        params.push(Number.parseInt(limit), Number.parseInt(offset))

        const [orders] = await db.execute(query, params)

        res.json({
            orders,
            pagination: {
                currentPage: Number.parseInt(page),
                limit: Number.parseInt(limit),
            },
        })
    } catch (error) {
        console.error("Get user orders error:", error)
        res.status(500).json({ message: "Server error while fetching orders" })
    }
})

// Get order details - অর্ডার ডিটেইলস পাওয়া
router.get("/:orderId", auth.authenticateToken, async (req, res) => {
    try {
        const orderId = req.params.orderId
        const userId = req.user.id

        // Build query based on user role - ইউজার রোল অনুযায়ী কুয়েরি তৈরি করা
        let orderQuery = `
      SELECT 
        o.id, o.total_amount, o.status, o.shipping_address, o.created_at, o.updated_at,
        u.name as customer_name, u.email as customer_email, u.phone as customer_phone
      FROM orders o
      JOIN users u ON o.user_id = u.id
      WHERE o.id = ?
    `

        const params = [orderId]

        // If customer, only show their own orders - যদি কাস্টমার হয়, শুধু তাদের অর্ডার দেখানো
        if (req.user.role === "customer") {
            orderQuery += " AND o.user_id = ?"
            params.push(userId)
        }

        const [orders] = await db.execute(orderQuery, params)

        if (orders.length === 0) {
            return res.status(404).json({ message: "Order not found" })
        }

        // Get order items - অর্ডার আইটেম পাওয়া
        const [orderItems] = await db.execute(
            `
      SELECT 
        oi.id, oi.quantity, oi.price,
        p.id as product_id, p.name as product_name, p.image_url
      FROM order_items oi
      JOIN products p ON oi.product_id = p.id
      WHERE oi.order_id = ?
    `,
            [orderId],
        )

        res.json({
            order: orders[0],
            items: orderItems,
        })
    } catch (error) {
        console.error("Get order details error:", error)
        res.status(500).json({ message: "Server error while fetching order details" })
    }
})

// Update order status (Admin only) - অর্ডার স্ট্যাটাস আপডেট করা (শুধু Admin)
router.put(
    "/:orderId/status",
    auth.authenticateToken,
    auth.requireAdmin,
    [
        body("status")
            .isIn(["pending", "confirmed", "shipped", "delivered", "cancelled"])
            .withMessage("Invalid status value"),
    ],
    async (req, res) => {
        try {
            const errors = validationResult(req)
            if (!errors.isEmpty()) {
                return res.status(400).json({ errors: errors.array() })
            }

            const orderId = req.params.orderId
            const { status } = req.body

            // Check if order exists - অর্ডার আছে কিনা চেক করা
            const [orders] = await db.execute("SELECT id, status FROM orders WHERE id = ?", [orderId])
            if (orders.length === 0) {
                return res.status(404).json({ message: "Order not found" })
            }

            // Update order status - অর্ডার স্ট্যাটাস আপডেট করা
            await db.execute("UPDATE orders SET status = ? WHERE id = ?", [status, orderId])

            res.json({
                message: "Order status updated successfully",
                orderId: Number.parseInt(orderId),
                newStatus: status,
                previousStatus: orders[0].status,
            })
        } catch (error) {
            console.error("Update order status error:", error)
            res.status(500).json({ message: "Server error while updating order status" })
        }
    },
)

// Get all orders (Admin only) - সব অর্ডার পাওয়া (শুধু Admin)
router.get("/admin/all", auth.authenticateToken, auth.requireAdmin, async (req, res) => {
    try {
        const { status, page = 1, limit = 20, sortBy = "created_at", sortOrder = "DESC" } = req.query

        let query = `
      SELECT 
        o.id, o.total_amount, o.status, o.created_at,
        u.name as customer_name, u.email as customer_email,
        COUNT(oi.id) as total_items
      FROM orders o
      JOIN users u ON o.user_id = u.id
      LEFT JOIN order_items oi ON o.id = oi.order_id
      WHERE 1=1
    `

        const params = []

        // Filter by status - স্ট্যাটাস দিয়ে ফিল্টার করা
        if (status) {
            query += " AND o.status = ?"
            params.push(status)
        }

        query += " GROUP BY o.id"

        // Sorting - সর্টিং
        const validSortFields = ["created_at", "total_amount", "status"]
        const sortField = validSortFields.includes(sortBy) ? sortBy : "created_at"
        const order = sortOrder.toUpperCase() === "ASC" ? "ASC" : "DESC"
        query += ` ORDER BY o.${sortField} ${order}`

        // Pagination - পেজিনেশন
        const offset = (page - 1) * limit
        query += " LIMIT ? OFFSET ?"
        params.push(Number.parseInt(limit), Number.parseInt(offset))

        const [orders] = await db.execute(query, params)

        // Get total count - টোটাল কাউন্ট পাওয়া
        let countQuery = "SELECT COUNT(*) as total FROM orders WHERE 1=1"
        const countParams = []

        if (status) {
            countQuery += " AND status = ?"
            countParams.push(status)
        }

        const [countResult] = await db.execute(countQuery, countParams)
        const totalOrders = countResult[0].total

        res.json({
            orders,
            pagination: {
                currentPage: Number.parseInt(page),
                totalPages: Math.ceil(totalOrders / limit),
                totalOrders,
                hasNext: page * limit < totalOrders,
                hasPrev: page > 1,
            },
        })
    } catch (error) {
        console.error("Get all orders error:", error)
        res.status(500).json({ message: "Server error while fetching orders" })
    }
})

const orderRoutes = router;

export default orderRoutes;
