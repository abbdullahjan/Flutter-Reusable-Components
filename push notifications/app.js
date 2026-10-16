// Code to be added on app.js

require('dotenv').config();
app.use(express.json());
app.use('/api/push', require('./push/pushRoutes'));