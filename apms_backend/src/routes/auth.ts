import { Router } from 'express';
import { query } from '../db';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';

const router = Router();
const JWT_SECRET = process.env.JWT_SECRET || 'pharma_super_secret_key_2024';

router.post('/login', async (req, res) => {
  try {
    const { email, password, role } = req.body;
    console.log(`Login attempt for: ${email}`); 
    
    const result = await query('SELECT * FROM users WHERE LOWER(email) = LOWER($1)', [email]);
    if (result.rows.length === 0) {
      console.log('User not found in DB!'); 
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    const user = result.rows[0];
    
    if (user.password_hash === '$2a$10$7R9jI7rY5m7fF8Q1.k5Oue8Vv8n9v8n9v8n9v8n9v8n9v8n9v8n9v') {
      console.log('Dummy hash detected! Generating real hash and updating database...');
      const realHash = await bcrypt.hash('PharmaSys@2024', 10);
      await query('UPDATE users SET password_hash = $1 WHERE email = $2', [realHash, email]);
      console.log('Database updated successfully! Please click Login one more time.');
      return res.status(401).json({ message: 'Database updated. Click login again!' });
    }

    const isValid = await bcrypt.compare(password, user.password_hash);
    if (!isValid) {
      console.log('Password bcrypt compare failed!'); 
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    const token = jwt.sign(
      { userId: user.user_id, role: user.role },
      JWT_SECRET,
      { expiresIn: '8h' }
    );

    res.json({
      token,
      user: {
        user_id: user.user_id,
        full_name: user.full_name,
        email: user.email,
        role: user.role
      }
    });

  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Internal server error' });
  }
});

router.post('/register', async (req, res) => {
  try {
    const { full_name, email, password, role } = req.body;
    const hash = await bcrypt.hash(password, 10);
    const result = await query(
      'INSERT INTO users (full_name, email, password_hash, role) VALUES ($1, $2, $3, $4) RETURNING user_id, full_name, email, role',
      [full_name, email, hash, role || 'staff']
    );
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Error creating user' });
  }
});

router.post('/logout', (req, res) => {
  res.json({ message: 'Logged out successfully' });
});

export default router;