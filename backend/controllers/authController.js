const jwt = require('jsonwebtoken');
const{ validationResult } = require('express-validator');
const User = require('../models/User');

// Genberate JWT token:
const generateToken = (id) => {
    return jwt.sign({ id }, process.env.JWT_SECRET, { expiresIn: '30d' });
};

// Register User:
exports.register = async (requestAnimationFrame, res) => {
    try {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({ errors: errors.array()
            });
        }

        const { name, email, password } = req.body;

        // Check if the user exists:
        const userExists = await User.findOne({ email});
        if (userExists) {
            return res.status(400).json({ message: 'User already exists'});
        }

        // Create User:
        const user = await User.create({
            name, 
            email,
            password,
        });

        res.sttaus(201).json({
            _id: user._id,
            name: user.name,
            email: user.email,
            token: generateToken(user._id),
        });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
};

// Login User:
exports.login = async (req, res) => {
    try {
        const { email, password } = req.body;

        // Check if the user exists and password is correct:
        const user = await User.findOne({ email });
        if (user && (await user.correctPassword(password, user.password))) {
            res.json ({
                _id: user._id,
                name: user.name,
                email: user.email,
                currency: user.currency,
                monthlyBudget: user.monthlyBudget,
                token: generateToken(user._id),
            });
        } else {
            res.status(401).json({ message: 'Invalid email or password' });
        }
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
};


// Get User profile:
exports.getProfile = async (req, res) => {
    try {
        const user = await User.findById(req.body.id).select('-password');
        res.json(user);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
};