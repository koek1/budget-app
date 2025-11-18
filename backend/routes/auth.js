const express = require('express');
const { body } = require('express-validator');
const { register, login, getProfile } = require('../controllers/authController');
const auth = require('../middleware/auth');

const router = express.Router();

router.post('/register', [
    body('name').not().isEmpty().withMessage('Name is required'),
    body('email').isEmail().withMessage('Invalid email adress'),
    body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters long')
], register);

router.post('/login', login);
router.get('/profile', auth, getProfile);

module.exports = router;