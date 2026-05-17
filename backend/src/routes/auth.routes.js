import { Router } from 'express';
import { protect } from '../middleware/auth.middleware.js';
import { signup, login, refresh, logout } from '../controllers/auth.controller.js';

const router = Router();

router.post('/signup', signup);
router.post('/login', login);
router.post('/refresh', refresh);
router.post('/logout', protect, logout);

export default router;
