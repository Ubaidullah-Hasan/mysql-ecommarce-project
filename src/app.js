import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import config from './app/config/index.js';
import authRoutes from './app/routes/auth.js';
import productRoutes from './app/routes/products.js';
import categoryRoutes from './app/routes/categories.js';
import cartRoutes from './app/routes/cart.js';

dotenv.config();

const app = express();

app.use(cors());
app.use(express.json());

// app.use(router);
// console.log('Router initialized', router);

// Routes - রুট সেটআপ
app.use("/api/auth", authRoutes);
app.use("/api/products", productRoutes);
app.use("/api/categories", categoryRoutes);
app.use("/api/cart", cartRoutes);
// app.use("/api/reports", reportRoutes)
// app.use("/api/relationships", relationshipRoutes);



app.get('/', (req, res) => {
  res.send('Welcome to the API');
});

app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).send('Something broke!');
});

app.use((req, res) => {
  res.status(404).send('Not Found');
});



const startServer = async () => {
  try {
    await import('./app/config/database.js');
    const PORT = config.port;
    app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
  } catch (error) {
    console.error("সার্ভার স্টার্ট করতে ব্যর্থ:", error);
    process.exit(1);
  }
};

startServer();




// // Start the server
// const PORT = config.port;
// app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
