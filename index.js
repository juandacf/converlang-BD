const express = require('express');
const cors = require('cors');
const pool = require('./db');

const app = express();


app.use(cors());
app.use(express.json());