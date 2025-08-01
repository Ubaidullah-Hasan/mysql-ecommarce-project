import mysql from 'mysql2/promise';
import config from './index.js';

const init = async () => {
    try {
        const connection = await mysql.createConnection({
            host: config.db_host,
            user: config.db_user,
            password: config.db_password,
        });

        await connection.query(`CREATE DATABASE IF NOT EXISTS ${config.db_name}`);
        console.log(`✅ Database '${config.db_name}' created or already exists.`);
        await connection.end();
    } catch (err) {
        console.error("❌ Error creating database:", err);
    }
};

init();
