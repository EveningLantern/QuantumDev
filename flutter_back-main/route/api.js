const express = require('express');
const router = express.Router();
const pool = require('../db');

//get data
router.get('/getAll', async (req, res) => {
    try {
        const result = await pool.query('SELECT * FROM insurance');
        res.json(result.rows);
    } catch (err) {
        res.status(500).send(err.message);
    }
});

//search by name and model
router.get('/search', async (req, res) => {
    const { name, model } = req.query;
    try {
        const result = await pool.query(
            'SELECT * FROM insurance WHERE name ILIKE $1 AND model ILIKE $2', //use Ilike to make the query case-insensitive
            [name, model]
        );
        res.json(result.rows);
    } catch (err) {
        res.status(500).send(err.message);
    }
});

//delete data
router.get('/delete', async(req, res) => {
    const {name, model, contact_number} = req.query;
    try {
        await pool.query(
            'DELETE FROM insurance WHERE name ILIKE $1 AND model ILIKE $2 AND contact_number ILIKE $3', //use Ilike to make the query case-insensitive
            [name, model, contact_number]
        );
        res.json({ status: 'deleted' });
    } catch (err) {
        res.status(500).send(err.message);
    }
});

//update
router.put('/update', async (req, res) => {
    const {name, model, vehicle_number} = req.query;
    const {due_date, contact_number, insurer} = req.body;

    // for validation in frontend
    if (!name || !model || !vehicle_number || !due_date || !contact_number || !insurer) {
        return res.status(400).json({ error: 'Missing one or more required fields' });
    }

    try {
        await pool.query(
            `UPDATE insurance 
       SET name = $1, model = $2, vehicle_number = $3, due_date = $4, contact_number = $5, insurer = $6 
       WHERE name ILIKE $1 AND model ILIKE $2 AND vehicle_number ILIKE $3`, //use Ilike to make the query case-insensitive
            [name, model, vehicle_number, due_date, contact_number, insurer]
        );
        res.json({status: 'updated'});
    } catch (err) {
        res.status(500).send(err.message);
    }
});

module.exports = router;