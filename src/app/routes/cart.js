import express from "express"
import { body, validationResult } from "express-validator"
import db from "../config/database.js"
import auth from "../middlewares/auth.js"


const router = express.Router()

// Get user's cart - ইউজারের কার্ট পাওয়া
router.get("/", auth.authenticateToken, auth.requireCustomer, async (req, res) => {
    try {
        const userId = req.user.id

        // Get cart items with product details - কার্ট আইটেম প্রোডাক্ট ডিটেইলস সহ পাওয়া
        const [cartItems] = await db.execute(
            `
      SELECT 
        c.id as cart_id,
        c.quantity,
        c.created_at as added_at,
        p.id as product_id,
        p.name as product_name,
        p.price,
        p.image_url,
        p.stock_quantity,
        (c.quantity * p.price) as subtotal
      FROM cart c
      JOIN products p ON c.product_id = p.id
      WHERE c.user_id = ?
      ORDER BY c.created_at DESC
    `,
            [userId],
        )

        // Calculate total amount - টোটাল পরিমাণ হিসাব করা
        const totalAmount = cartItems.reduce((sum, item) => sum + Number.parseFloat(item.subtotal), 0)

        res.json({
            cartItems,
            summary: {
                totalItems: cartItems.length,
                totalQuantity: cartItems.reduce((sum, item) => sum + item.quantity, 0),
                totalAmount: totalAmount.toFixed(2),
            },
        })
    } catch (error) {
        console.error("Get cart error:", error)
        res.status(500).json({ message: "Server error while fetching cart" })
    }
})

// Add item to cart - কার্টে আইটেম যোগ করা
router.post(
    "/add",
    auth.authenticateToken,
    auth.requireCustomer,
    [
        body("product_id").isInt().withMessage("Product ID must be an integer"),
        body("quantity").isInt({ min: 1 }).withMessage("Quantity must be at least 1"),
    ],
    async (req, res) => {
        try {
            const errors = validationResult(req)
            if (!errors.isEmpty()) {
                return res.status(400).json({ errors: errors.array() })
            }

            const userId = req.user.id
            const { product_id, quantity } = req.body

            // Check if product exists and has sufficient stock - প্রোডাক্ট আছে এবং স্টক যথেষ্ট কিনা চেক করা
            const [products] = await db.execute("SELECT id, name, price, stock_quantity FROM products WHERE id = ?", [
                product_id,
            ])

            if (products.length === 0) {
                return res.status(404).json({ message: "Product not found" })
            }

            const product = products[0]

            if (product.stock_quantity < quantity) {
                return res.status(400).json({
                    message: `Insufficient stock. Only ${product.stock_quantity} items available`,
                })
            }

            // Check if item already exists in cart - আইটেম আগে থেকে কার্টে আছে কিনা চেক করা
            const [existingCartItems] = await db.execute(
                "SELECT id, quantity FROM cart WHERE user_id = ? AND product_id = ?",
                [userId, product_id],
            )

            if (existingCartItems.length > 0) {
                // Update existing cart item - বিদ্যমান কার্ট আইটেম আপডেট করা
                const newQuantity = existingCartItems[0].quantity + quantity

                if (product.stock_quantity < newQuantity) {
                    return res.status(400).json({
                        message: `Cannot add ${quantity} more items. Only ${product.stock_quantity - existingCartItems[0].quantity} more items can be added`,
                    })
                }

                await db.execute("UPDATE cart SET quantity = ? WHERE id = ?", [newQuantity, existingCartItems[0].id])

                res.json({
                    message: "Cart item updated successfully",
                    action: "updated",
                    newQuantity,
                })
            } else {
                // Add new cart item - নতুন কার্ট আইটেম যোগ করা
                await db.execute("INSERT INTO cart (user_id, product_id, quantity) VALUES (?, ?, ?)", [
                    userId,
                    product_id,
                    quantity,
                ])

                res.status(201).json({
                    message: "Item added to cart successfully",
                    action: "added",
                    quantity,
                })
            }
        } catch (error) {
            console.error("Add to cart error:", error)
            res.status(500).json({ message: "Server error while adding to cart" })
        }
    },
)

// Update cart item quantity - কার্ট আইটেমের পরিমাণ আপডেট করা
router.put(
    "/update/:cartId",
    auth.authenticateToken,
    auth.requireCustomer,
    [body("quantity").isInt({ min: 1 }).withMessage("Quantity must be at least 1")],
    async (req, res) => {
        try {
            const errors = validationResult(req)
            if (!errors.isEmpty()) {
                return res.status(400).json({ errors: errors.array() })
            }

            const userId = req.user.id
            const cartId = req.params.cartId
            const { quantity } = req.body

            // Check if cart item belongs to user - কার্ট আইটেম ইউজারের কিনা চেক করা
            const [cartItems] = await db.execute(
                `
      SELECT c.id, c.product_id, p.stock_quantity, p.name
      FROM cart c
      JOIN products p ON c.product_id = p.id
      WHERE c.id = ? AND c.user_id = ?
    `,
                [cartId, userId],
            )

            if (cartItems.length === 0) {
                return res.status(404).json({ message: "Cart item not found" })
            }

            const cartItem = cartItems[0]

            // Check stock availability - স্টক উপলব্ধতা চেক করা
            if (cartItem.stock_quantity < quantity) {
                return res.status(400).json({
                    message: `Insufficient stock. Only ${cartItem.stock_quantity} items available`,
                })
            }

            // Update cart item quantity - কার্ট আইটেমের পরিমাণ আপডেট করা
            await db.execute("UPDATE cart SET quantity = ? WHERE id = ?", [quantity, cartId])

            res.json({
                message: "Cart item quantity updated successfully",
                newQuantity: quantity,
            })
        } catch (error) {
            console.error("Update cart error:", error)
            res.status(500).json({ message: "Server error while updating cart" })
        }
    },
)

// Remove item from cart - কার্ট থেকে আইটেম সরানো
router.delete("/remove/:cartId", auth.authenticateToken, auth.requireCustomer, async (req, res) => {
    try {
        const userId = req.user.id
        const cartId = req.params.cartId

        // Check if cart item belongs to user - কার্ট আইটেম ইউজারের কিনা চেক করা
        const [cartItems] = await db.execute("SELECT id FROM cart WHERE id = ? AND user_id = ?", [cartId, userId])

        if (cartItems.length === 0) {
            return res.status(404).json({ message: "Cart item not found" })
        }

        // Remove cart item - কার্ট আইটেম সরানো
        await db.execute("DELETE FROM cart WHERE id = ?", [cartId])

        res.json({
            message: "Item removed from cart successfully",
        })
    } catch (error) {
        console.error("Remove from cart error:", error)
        res.status(500).json({ message: "Server error while removing from cart" })
    }
})

// 
const cartRoutes = router

export default cartRoutes
