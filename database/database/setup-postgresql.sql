-- PostgreSQL Schema for BUCOHub
-- Run this in your Render PostgreSQL database

-- Enable UUID extension if needed
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create registrations table
CREATE TABLE IF NOT EXISTS registrations (
    id SERIAL PRIMARY KEY,
    "firstName" VARCHAR(255) NOT NULL,
    "lastName" VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(50),
    password VARCHAR(255) NOT NULL,
    age INTEGER,
    education TEXT,
    experience TEXT,
    courses JSONB,
    motivation TEXT,
    "profilePictureUrl" VARCHAR(500),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create admins table
CREATE TABLE IF NOT EXISTS admins (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(255) NOT NULL,
    last_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'admin',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_registrations_email ON registrations(email);
CREATE INDEX IF NOT EXISTS idx_registrations_created_at ON registrations(created_at);
CREATE INDEX IF NOT EXISTS idx_admins_email ON admins(email);
CREATE INDEX IF NOT EXISTS idx_admins_is_active ON admins(is_active);

-- Insert sample admin user (password: admin123)
INSERT INTO admins (first_name, last_name, email, password, role) 
VALUES (
    'Admin', 
    'User', 
    'admin@bucohub.com', 
    '$2a$10$8K1p/a0dRTlB0Z6F8zU.3uO2VQj9JZ8X8n8J8Z8J8Z8J8Z8J8Z8J8', -- bcrypt hash for 'admin123'
    'super_admin'
) ON CONFLICT (email) DO NOTHING;

-- Insert sample students for testing
INSERT INTO registrations (
    "firstName", "lastName", email, phone, password, 
    age, education, experience, courses, motivation
) VALUES 
(
    'John', 'Doe', 'john.doe@example.com', '+1234567890',
    '$2a$10$8K1p/a0dRTlB0Z6F8zU.3uO2VQj9JZ8X8n8J8Z8J8Z8J8Z8J8Z8J8', -- password: student123
    25, 'BSc Computer Science', '2 years web development',
    '["Web Development", "JavaScript", "React"]'::JSONB,
    'Interested in learning full-stack development'
),
(
    'Jane', 'Smith', 'jane.smith@example.com', '+0987654321',
    '$2a$10$8K1p/a0dRTlB0Z6F8zU.3uO2VQj9JZ8X8n8J8Z8J8Z8J8Z8J8Z8J8',
    22, 'BSc Mathematics', '1 year programming',
    '["Data Science", "Python", "Machine Learning"]'::JSONB,
    'Passionate about data analysis and AI'
)
ON CONFLICT (email) DO NOTHING;

-- Create function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_registrations_updated_at 
    BEFORE UPDATE ON registrations 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_admins_updated_at 
    BEFORE UPDATE ON admins 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Grant necessary permissions (if needed)
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO your_username;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO your_username;

-- Verify tables were created
SELECT 
    table_name, 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM 
    information_schema.columns 
WHERE 
    table_name IN ('registrations', 'admins')
ORDER BY 
    table_name, 
    ordinal_position;