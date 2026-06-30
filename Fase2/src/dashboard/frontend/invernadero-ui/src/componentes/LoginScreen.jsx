import { useState } from 'react';
import { Lock, LogIn, User } from 'lucide-react';

const DEMO_USER = 'grupo3';
const DEMO_PASSWORD = '12345';

export function LoginScreen({ onLogin }) {
  const [usuario, setUsuario] = useState('');
  const [contrasena, setContrasena] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = (event) => {
    event.preventDefault();

    if (!usuario.trim() || !contrasena.trim()) {
      setError('Ingresa usuario y contrasena.');
      return;
    }

    setError('');
    setLoading(true);

    window.setTimeout(() => {
      if (
        usuario.trim() === DEMO_USER &&
        contrasena === DEMO_PASSWORD
      ) {
        onLogin({
          usuario: DEMO_USER,
          loginAt: new Date().toISOString()
        });
        setLoading(false);
        return;
      }

      setError('Usuario o contrasena incorrectos.');
      setLoading(false);
    }, 350);
  };

  return (
    <main className="min-h-screen bg-slate-50 flex items-center justify-center px-4">
      <section className="w-full max-w-md bg-white border border-slate-200 shadow-sm rounded-2xl p-6">
        <div className="flex items-center gap-3 mb-6">
          <div className="p-3 rounded-xl bg-emerald-100 text-emerald-700">
            <Lock className="w-6 h-6" />
          </div>

          <div>
            <h1 className="text-xl font-bold text-slate-900">
              Invernadero Inteligente IoT
            </h1>
            <p className="text-sm text-slate-500">
              Acceso del dashboard
            </p>
          </div>
        </div>

        <form
          className="space-y-4"
          onSubmit={handleSubmit}
        >
          <label className="block">
            <span className="text-sm font-semibold text-slate-700">
              Usuario
            </span>
            <div className="mt-1 flex items-center gap-2 rounded-lg border border-slate-200 px-3 py-2 focus-within:ring-2 focus-within:ring-emerald-500">
              <User className="w-4 h-4 text-slate-400" />
              <input
                value={usuario}
                onChange={(event) => setUsuario(event.target.value)}
                className="w-full outline-none text-slate-800"
                autoComplete="username"
              />
            </div>
          </label>

          <label className="block">
            <span className="text-sm font-semibold text-slate-700">
              Contrasena
            </span>
            <div className="mt-1 flex items-center gap-2 rounded-lg border border-slate-200 px-3 py-2 focus-within:ring-2 focus-within:ring-emerald-500">
              <Lock className="w-4 h-4 text-slate-400" />
              <input
                value={contrasena}
                onChange={(event) => setContrasena(event.target.value)}
                type="password"
                className="w-full outline-none text-slate-800"
                autoComplete="current-password"
              />
            </div>
          </label>

          {error && (
            <p className="rounded-lg bg-rose-50 px-3 py-2 text-sm font-semibold text-rose-700">
              {error}
            </p>
          )}

          <button
            type="submit"
            disabled={loading}
            className="w-full inline-flex items-center justify-center gap-2 rounded-lg bg-emerald-600 px-4 py-2.5 font-bold text-white hover:bg-emerald-700 disabled:cursor-wait disabled:bg-emerald-300"
          >
            <LogIn className="w-4 h-4" />
            {loading ? 'Validando...' : 'Iniciar sesion'}
          </button>
        </form>
      </section>
    </main>
  );
}

export const TEST_USER = DEMO_USER;
