const mongoose = require('mongoose');

module.exports = mongoose.model('Subscription', new mongoose.Schema({
  endpoint: { type: String, required: true, unique: true },
  keys: { p256dh: String, auth: String },
  userId: { type: String, index: true, default: null },
}, { timestamps: true }));