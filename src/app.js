import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import config from './app/config/index.js';

dotenv.config();

const app = express();

app.use(cors());
app.use(express.json());


const PORT = config.port || 5000;
app.listen(PORT, () => console.log(`Server running on port ${config.port}`));
