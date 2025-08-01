import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import config from './app/config/index.js';
import router from './app/routes/index.js';
import authRoutes from './app/routes/auth.js';

dotenv.config();

const app = express();

app.use(cors());
app.use(express.json());

// app.use(router);
// console.log('Router initialized', router);

// Routes - রুট সেটআপ
app.use("/api/auth", authRoutes);
// app.use("/api/products", productRoutes)
// app.use("/api/cart", cartRoutes)
// app.use("/api/orders", orderRoutes)
// app.use("/api/categories", categoryRoutes)
// app.use("/api/reports", reportRoutes)
// app.use("/api/relationships", relationshipRoutes)



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

// Start the server

const PORT = config.port;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
