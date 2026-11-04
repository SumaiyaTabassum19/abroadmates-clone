const API_BASE_URL = 'http://localhost:5000/api';
const loginForm = document.getElementById('loginForm');
const registerForm = document.getElementById('registerForm');
const notice = document.getElementById('authNotice');
const tabs = [...document.querySelectorAll('.auth-tab')];

document.getElementById('year').textContent = new Date().getFullYear();

function showNotice(message, type = 'info') {
  notice.textContent = message;
  notice.className = `auth-notice${type === 'info' ? '' : ` ${type}`}`;
  notice.hidden = false;
}

function setMode(mode) {
  const isLogin = mode === 'login';
  loginForm.hidden = !isLogin;
  registerForm.hidden = isLogin;
  tabs.forEach(tab => {
    const active = tab.dataset.mode === mode;
    tab.classList.toggle('active', active);
    tab.setAttribute('aria-selected', String(active));
  });
  notice.hidden = true;
}

tabs.forEach(tab => tab.addEventListener('click', () => setMode(tab.dataset.mode)));

async function apiRequest(path, payload, token) {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    method: path.endsWith('/me') ? 'GET' : 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {})
    },
    ...(payload ? { body: JSON.stringify(payload) } : {})
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data.message || `Request failed (${response.status})`);
  return data;
}

loginForm.addEventListener('submit', async event => {
  event.preventDefault();
  const button = loginForm.querySelector('button[type="submit"]');
  button.disabled = true;
  button.textContent = 'Signing in…';
  try {
    const data = await apiRequest('/auth/login', {
      email: loginForm.email.value.trim(),
      password: loginForm.password.value
    });
    localStorage.setItem('abroadmates_token', data.token);
    localStorage.setItem('abroadmates_user', JSON.stringify(data.user));
    showNotice('Login successful. Opening your dashboard…', 'success');
    window.location.href = data.user.role === 'Mentor' ? 'mentor-dashboard.html' : 'student-dashboard.html';
  } catch (error) {
    showNotice(error.message, 'error');
  } finally {
    button.disabled = false;
    button.innerHTML = 'Log in <span>→</span>';
  }
});

registerForm.addEventListener('submit', async event => {
  event.preventDefault();
  const password = registerForm.password.value;
  const confirmPassword = registerForm.confirmPassword.value;
  if (password !== confirmPassword) {
    showNotice('The passwords do not match. Please check and try again.', 'error');
    return;
  }
  const button = registerForm.querySelector('button[type="submit"]');
  button.disabled = true;
  button.textContent = 'Creating account…';
  try {
    const data = await apiRequest('/auth/register', {
      fullName: registerForm.fullName.value.trim(),
      email: registerForm.email.value.trim(),
      password,
      role: registerForm.role.value
    });
    showNotice(data.message || 'Account created. Please log in.', 'success');
    registerForm.reset();
    setMode('login');
    loginForm.email.value = data.user?.email || '';
    showNotice(data.message || 'Account created. Please log in.', 'success');
  } catch (error) {
    showNotice(error.message, 'error');
  } finally {
    button.disabled = false;
    button.innerHTML = 'Create account <span>→</span>';
  }
});
