const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const apiRoutes = require('./route/api');

dotenv.config();
const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());
app.use('/', apiRoutes);

app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
})