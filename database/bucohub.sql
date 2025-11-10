-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

--
-- Table structure for table `admins`
--

DROP TABLE IF EXISTS admins CASCADE;
CREATE TABLE admins (
  id SERIAL PRIMARY KEY,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE,
  password VARCHAR(255) NOT NULL,
  role VARCHAR(20) DEFAULT 'admin' CHECK (role IN ('super_admin', 'admin', 'moderator')),
  is_active BOOLEAN DEFAULT TRUE,
  last_login TIMESTAMP NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for admins
CREATE TRIGGER update_admins_updated_at BEFORE UPDATE ON admins 
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

--
-- Table structure for table `courses`
--

DROP TABLE IF EXISTS courses CASCADE;
CREATE TABLE courses (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  duration_weeks INTEGER,
  price DECIMAL(10,2),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER update_courses_updated_at BEFORE UPDATE ON courses 
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

--
-- Table structure for table `registrations`
--

DROP TABLE IF EXISTS registrations CASCADE;
CREATE TABLE registrations (
  id SERIAL PRIMARY KEY,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE,
  phone VARCHAR(20),
  password VARCHAR(255) NOT NULL,
  age INTEGER,
  education VARCHAR(255),
  experience TEXT,
  courses JSONB,
  motivation TEXT,
  profile_picture_url VARCHAR(500),
  is_active BOOLEAN DEFAULT TRUE,
  email_verified BOOLEAN DEFAULT FALSE,
  last_login TIMESTAMP NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER update_registrations_updated_at BEFORE UPDATE ON registrations 
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

--
-- Table structure for table `student_courses`
--

DROP TABLE IF EXISTS student_courses CASCADE;
CREATE TABLE student_courses (
  id SERIAL PRIMARY KEY,
  student_id INTEGER NOT NULL REFERENCES registrations(id) ON DELETE CASCADE,
  course_id INTEGER NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  enrollment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  progress_percentage INTEGER DEFAULT 0,
  status VARCHAR(20) DEFAULT 'enrolled' CHECK (status IN ('enrolled', 'in_progress', 'completed', 'dropped')),
  completed_at TIMESTAMP NULL,
  UNIQUE(student_id, course_id)
);

--
-- Table structure for table `audit_log`
--

DROP TABLE IF EXISTS audit_log CASCADE;
CREATE TABLE audit_log (
  id SERIAL PRIMARY KEY,
  admin_id INTEGER REFERENCES admins(id),
  action VARCHAR(100) NOT NULL,
  table_name VARCHAR(100),
  record_id INTEGER,
  old_values JSONB,
  new_values JSONB,
  ip_address VARCHAR(45),
  user_agent TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

--
-- Table structure for table `password_resets`
--

DROP TABLE IF EXISTS password_resets CASCADE;
CREATE TABLE password_resets (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) NOT NULL,
  token VARCHAR(255) NOT NULL,
  expires_at TIMESTAMP NOT NULL,
  used BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

--
-- Create indexes
--

CREATE INDEX idx_admins_active ON admins(is_active);
CREATE INDEX idx_admin_date ON audit_log(admin_id, created_at);
CREATE INDEX idx_action ON audit_log(action);
CREATE INDEX idx_audit_log_created ON audit_log(created_at DESC);
CREATE INDEX idx_course_status ON student_courses(course_id, status);
CREATE INDEX idx_student_status ON student_courses(student_id, status);
CREATE INDEX idx_student_courses_progress ON student_courses(progress_percentage);
CREATE INDEX idx_email_token ON password_resets(email, token);
CREATE INDEX idx_expires ON password_resets(expires_at);
CREATE INDEX idx_registrations_email ON registrations(email);
CREATE INDEX idx_registrations_name ON registrations(first_name, last_name);
CREATE INDEX idx_registrations_created_at ON registrations(created_at);
CREATE INDEX idx_registrations_phone ON registrations(phone);
CREATE INDEX idx_registrations_active ON registrations(is_active);

--
-- Procedures
--

CREATE OR REPLACE FUNCTION register_student(
  p_first_name VARCHAR(100),
  p_last_name VARCHAR(100),
  p_email VARCHAR(255),
  p_phone VARCHAR(20),
  p_password VARCHAR(255),
  p_age INTEGER,
  p_education VARCHAR(255),
  p_experience TEXT,
  p_courses JSONB,
  p_motivation TEXT,
  p_profile_picture_url VARCHAR(500)
)
RETURNS INTEGER AS $$
DECLARE
  new_student_id INTEGER;
BEGIN
  INSERT INTO registrations (
    first_name, last_name, email, phone, password,
    age, education, experience, courses, motivation, profile_picture_url
  ) VALUES (
    p_first_name, p_last_name, p_email, p_phone, p_password,
    p_age, p_education, p_experience, p_courses, p_motivation, p_profile_picture_url
  ) RETURNING id INTO new_student_id;
  
  RETURN new_student_id;
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error registering student: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

--
-- Views
--

CREATE OR REPLACE VIEW course_enrollment_stats AS
SELECT 
  c.id,
  c.name,
  c.duration_weeks,
  COUNT(sc.id) AS total_enrollments,
  AVG(sc.progress_percentage) AS avg_progress,
  SUM(CASE WHEN sc.status = 'completed' THEN 1 ELSE 0 END) AS completed_count
FROM courses c
LEFT JOIN student_courses sc ON c.id = sc.course_id
WHERE c.is_active = true
GROUP BY c.id, c.name, c.duration_weeks;

CREATE OR REPLACE VIEW student_summary AS
SELECT 
  r.id,
  CONCAT(r.first_name, ' ', r.last_name) AS full_name,
  r.email,
  r.phone,
  r.age,
  r.education,
  COUNT(sc.id) AS enrolled_courses,
  AVG(sc.progress_percentage) AS avg_progress,
  r.created_at
FROM registrations r
LEFT JOIN student_courses sc ON (r.id = sc.student_id AND sc.status != 'dropped')
WHERE r.is_active = true
GROUP BY r.id, r.first_name, r.last_name, r.email, r.phone, r.age, r.education, r.created_at;

--
-- Insert sample data
--

INSERT INTO admins (first_name, last_name, email, password, role, is_active) VALUES
('System', 'Administrator', 'admin@bucohub.com', '$2a$10$8K1p/a0dRL1B0VZQY2Qz3uYQYQYQYQYQYQYQYQYQYQYQYQYQYQYQ', 'super_admin', TRUE),
('SOLOMON', 'ADIELE', 'solomonadiele1@gmail.com', '$2a$10$ah7OludqWYY2nyYYsoXY5u1OhSBh7RkQBGjM40tnRrfv9fmzmFecS', 'admin', TRUE);

INSERT INTO courses (name, description, duration_weeks, price, is_active) VALUES
('UI/UX Design', 'Learn user interface and user experience design principles', 12, 299.99, TRUE),
('Front-end Development', 'Master HTML, CSS, JavaScript and modern frameworks', 16, 399.99, TRUE),
('Back-end Development', 'Learn server-side programming with Node.js and databases', 20, 449.99, TRUE),
('Full Stack Development', 'Complete web development from front-end to back-end', 24, 599.99, TRUE),
('Data Science', 'Data analysis, machine learning and visualization', 20, 499.99, TRUE),
('Digital Marketing', 'SEO, social media marketing, and analytics', 12, 349.99, TRUE),
('Mobile App Development', 'Build iOS and Android applications', 18, 449.99, TRUE),
('Artificial Intelligence', 'Machine learning and AI fundamentals', 22, 549.99, TRUE),
('Cybersecurity', 'Network security and ethical hacking', 16, 499.99, TRUE);

INSERT INTO registrations (first_name, last_name, email, phone, password, age, education, experience, courses, motivation, profile_picture_url) VALUES
('ADIELE', 'SOLOMON', 'chimereucheyaadiele1@gmail.com', '08069383370', '$2a$10$MvPcwZO1nI9SLNOo4xMPEepL6RdfJ5.6hntVjMbY792iNJZiPCzy6', 28, 'Bachelor''s Degree', 'HR Management System, Teacher, Full-stack Developer', '["Web Development", "Mobile App Development", "Data Science"]', 'to be productive in life.', '/uploads/profile-1U4A1885-JPG-1761224625127-528835114.jpg'),
('SOLOMON', 'ADIELE', 'solomonadiele1@gmail.com', '08069383370', '$2a$10$LtiYcnMkYazV9mNQ.SW9Y.raKwjfOyVogDRLVrl/ZtdIeMFrkB61y', 26, 'Bachelor''s Degree', 'HR Management System, Teacher, Full-stack Developer', '["Web Development", "Mobile App Development"]', 'To acquire more knowledge', '/uploads/profile-1U4A1781-JPG-1761226177590-882381210.jpg');