#!/usr/bin/env bash

# This script is used to create a new T3 - Xode v1.0 project.
# It will create a new project with the following features:
# - Login and Register pages
# - Home page
# - Prisma ORM
# - Tailwind CSS
# - Shadcn UI
# - BetterAuth

# Run with : curl -sSL https://github.com/KNkoe/Starter-script/blob/04f144acae3ad3522ce5128e1eebff1193d81a6c/starter.sh | bash

set -e

PROJECT=$1
if [ -z "$PROJECT" ]; then
  echo "Usage: $0 <project-name>"
  exit 1
fi

# 1. Create T3 Stack project with App Router
npx create-t3-app@latest "$PROJECT" --CI --trpc --prisma --tailwind --dbProvider postgres --appRouter --noInstall
cd "$PROJECT"

# 2. Configure @ import alias in tsconfig.json
if [ -f "tsconfig.json" ]; then
  if ! grep -q '"@/\*"' tsconfig.json; then
    echo "⚠️  Adding @ import alias to tsconfig.json manually..."
    echo "Please add the following to your tsconfig.json compilerOptions:"
    echo '    "paths": {'
    echo '      "@/*": ["./src/*"]'
    echo '    },'
  else
    echo "✅ @ import alias already configured"
  fi
fi

# 3. Check if alias is added
echo "--------------------------------"
echo "Checking if alias is added..."
echo "--------------------------------"
echo "✅ Are you done with adding alias? (y/n)"
echo "--------------------------------"
read done
if [ "$done" != "y" ]; then
  echo "Please add the following to your tsconfig.json compilerOptions:"
  echo '    "paths": {'
  echo '      "@/*": ["./src/*"]'
  echo '    },'
fi

# 3. Initialize shadcn/ui (default options, no interactivity)
npx shadcn@latest init -y

# 4. Add shadcn components
npx shadcn@latest add button input card label

# 5. Install BetterAuth
npm install better-auth

# 6. Create directories for BetterAuth and auth pages (inside src)
mkdir -p src/lib
mkdir -p "src/app/api/auth/[...all]"
mkdir -p "src/app/(auth)/login"
mkdir -p "src/app/(auth)/register"

# 7. Update Prisma schema for BetterAuth
rm -rf prisma

# 8. Add BetterAuth environment variables
cat >> .env <<'EOF'

# BetterAuth Configuration
BETTER_AUTH_SECRET="your-secret-key-change-this-in-production"
BETTER_AUTH_URL="http://localhost:3000"
BETTER_AUTH_TELEMETRY=0
EOF

# 9. Configure BetterAuth server instance with Prisma
cat > src/lib/auth.ts <<'EOF'
import { betterAuth } from "better-auth";
import { prismaAdapter } from "better-auth/adapters/prisma";
import { db } from "@/server/db"; // T3 Prisma client

export const auth = betterAuth({
  database: prismaAdapter(db, {
    provider: "postgresql",
  }),
  emailAndPassword: {
    enabled: true,
  },
  session: {
    expiresIn: 60 * 60 * 24 * 7, // 7 days
  },
  secret: process.env.BETTER_AUTH_SECRET!,
  telemetry: { 
    enabled: false 
  },
  socialProviders: {},
});
EOF

# 10. Create BetterAuth API route
cat > "src/app/api/auth/[...all]/route.ts" <<'EOF'
import { auth } from "@/lib/auth";
import { toNextJsHandler } from "better-auth/next-js";

export const { GET, POST } = toNextJsHandler(auth);
EOF

# 11. Create BetterAuth client helper using env
cat > src/lib/auth-client.ts <<'EOF'
import { createAuthClient } from "better-auth/react";

export const authClient = createAuthClient({
  baseURL: process.env.BETTER_AUTH_URL || "http://localhost:3000",
});
EOF

# 12. Generate Prisma client and push database changes
npx @better-auth/cli generate

# 12.1. Append custom models to Prisma schema
cat >> "prisma/schema.prisma" <<'EOF'

model Post {
    id        Int      @id @default(autoincrement())
    name      String
    createdAt DateTime @default(now())
    updatedAt DateTime @updatedAt

    @@index([name])
}
EOF

# 12.2 Generate Prisma client and push database changes
npm run db:push --force-reset

# 13. Create App Router login page
cat > "src/app/(auth)/login/page.tsx" <<'EOF'
"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { cn } from "@/lib/utils";
import { authClient } from "@/lib/auth-client";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

export function LoginForm({
  className,
  ...props
}: React.ComponentProps<"div">) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [message, setMessage] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const router = useRouter();

  async function handleLogin(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (!email || !password) {
      setMessage("Please fill in all fields");
      return;
    }

    setIsLoading(true);
    setMessage("");

    try {
      const result = await authClient.signIn.email({ email, password });
      if (result.data) {
        setMessage("Login successful!");
        router.push("/"); // Redirect to home page
      } else if (result.error) {
        setMessage(result.error.message || "Login failed");
      }
    } catch (err: any) {
      setMessage(err?.message || "An unexpected error occurred");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className={cn("flex flex-col gap-6", className)} {...props}>
     <Card className="overflow-hidden p-0">
        <CardContent className="grid p-0 md:grid-cols-2">
          <form className="p-6 md:p-8 w-full" onSubmit={handleLogin}>
            <div className="flex flex-col gap-6">
              <div className="flex flex-col items-center text-center">
                <h1 className="text-2xl font-bold">Welcome back</h1>
                <p className="text-muted-foreground text-balance">
                  Login to your Starter Inc account
                </p>
              </div>
              <div className="grid gap-3">
                <Label htmlFor="email">Email</Label>
                <Input
                  id="email"
                  type="email"
                  placeholder="m@example.com"
                  required
                  value={email}
                  onChange={e => setEmail(e.target.value)}
                  disabled={isLoading}
                  autoComplete="email"
                />
              </div>
              <div className="grid gap-3">
                <div className="flex items-center">
                  <Label htmlFor="password">Password</Label>
                  <a
                    href="#"
                    className="ml-auto text-sm underline-offset-2 hover:underline"
                  >
                    Forgot your password?
                  </a>
                </div>
                <Input
                  id="password"
                  type="password"
                  required
                  value={password}
                  onChange={e => setPassword(e.target.value)}
                  disabled={isLoading}
                  autoComplete="current-password"
                />
              </div>
              <Button type="submit" className="w-full" disabled={isLoading}>
                {isLoading ? "Signing In..." : "Login"}
              </Button>
              {message && (
                <p
                  className={`mt-2 text-sm ${
                    message.includes("successful")
                      ? "text-green-600"
                      : "text-red-600"
                  }`}
                >
                  {message}
                </p>
              )}
              <div className="after:border-border relative text-center text-sm after:absolute after:inset-0 after:top-1/2 after:z-0 after:flex after:items-center after:border-t">
                <span className="bg-card text-muted-foreground relative z-10 px-2">
                  Or continue with
                </span>
              </div>
              <div className="grid grid-cols-3 gap-4">
                <Button variant="outline" type="button" className="w-full">
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" className="h-5 w-5">
                    <path
                      d="M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701"
                      fill="currentColor"
                    />
                  </svg>
                  <span className="sr-only">Login with Apple</span>
                </Button>
                <Button variant="outline" type="button" className="w-full">
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" className="h-5 w-5">
                    <path
                      d="M12.48 10.92v3.28h7.84c-.24 1.84-.853 3.187-1.787 4.133-1.147 1.147-2.933 2.4-6.053 2.4-4.827 0-8.6-3.893-8.6-8.72s3.773-8.72 8.6-8.72c2.6 0 4.507 1.027 5.907 2.347l2.307-2.307C18.747 1.44 16.133 0 12.48 0 5.867 0 .307 5.387.307 12s5.56 12 12.173 12c3.573 0 6.267-1.173 8.373-3.36 2.16-2.16 2.84-5.213 2.84-7.667 0-.76-.053-1.467-.173-2.053H12.48z"
                      fill="currentColor"
                    />
                  </svg>
                  <span className="sr-only">Login with Google</span>
                </Button>
                <Button variant="outline" type="button" className="w-full">
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" className="h-5 w-5">
                    <path
                      d="M6.915 4.03c-1.968 0-3.683 1.28-4.871 3.113C.704 9.208 0 11.883 0 14.449c0 .706.07 1.369.21 1.973a6.624 6.624 0 0 0 .265.86 5.297 5.297 0 0 0 .371.761c.696 1.159 1.818 1.927 3.593 1.927 1.497 0 2.633-.671 3.965-2.444.76-1.012 1.144-1.626 2.663-4.32l.756-1.339.186-.325c.061.1.121.196.183.3l2.152 3.595c.724 1.21 1.665 2.556 2.47 3.314 1.046.987 1.992 1.22 3.06 1.22 1.075 0 1.876-.355 2.455-.843a3.743 3.743 0 0 0 .81-.973c.542-.939.861-2.127.861-3.745 0-2.72-.681-5.357-2.084-7.45-1.282-1.912-2.957-2.93-4.716-2.93-1.047 0-2.088.467-3.053 1.308-.652.57-1.257 1.29-1.82 2.05-.69-.875-1.335-1.547-1.958-2.056-1.182-.966-2.315-1.303-3.454-1.303zm10.16 2.053c1.147 0 2.188.758 2.992 1.999 1.132 1.748 1.647 4.195 1.647 6.4 0 1.548-.368 2.9-1.839 2.9-.58 0-1.027-.23-1.664-1.004-.496-.601-1.343-1.878-2.832-4.358l-.617-1.028a44.908 44.908 0 0 0-1.255-1.98c.07-.109.141-.224.211-.327 1.12-1.667 2.118-2.602 3.358-2.602zm-10.201.553c1.265 0 2.058.791 2.675 1.446.307.327.737.871 1.234 1.579l-1.02 1.566c-.757 1.163-1.882 3.017-2.837 4.338-1.191 1.649-1.81 1.817-2.486 1.817-.524 0-1.038-.237-1.383-.794-.263-.426-.464-1.13-.464-2.046 0-2.221.63-4.535 1.66-6.088.454-.687.964-1.226 1.533-1.533a2.264 2.264 0 0 1 1.088-.285z"
                      fill="currentColor"
                    />
                  </svg>
                  <span className="sr-only">Login with Meta</span>
                </Button>
              </div>
              <div className="text-center text-sm">
                Don&apos;t have an account?{" "}
                <a href="/register" className="underline underline-offset-4">
                  Sign up
                </a>
              </div>
            </div>
          </form>
          <div className="bg-muted relative hidden md:block">
            <img
              src="https://ui.shadcn.com/placeholder.svg"
              alt="Image"
              className="absolute inset-0 h-full w-full object-cover dark:brightness-[0.2] dark:grayscale"
            />
          </div>
        </CardContent>
      </Card>
    </div>
  );
}

export default function LoginPage() {
  return (
    <div className="bg-muted flex min-h-svh flex-col items-center justify-center p-6 md:p-10">
      <div className="w-full max-w-md md:max-w-3xl">
        <LoginForm />
      </div>
    </div>
  )
}
EOF

# 14. Create App Router register page
cat > "src/app/(auth)/register/page.tsx" <<'EOF'
"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { cn } from "@/lib/utils";
import { authClient } from "@/lib/auth-client";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

export function RegisterForm({
  className,
  ...props
}: React.ComponentProps<"div">) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [name, setName] = useState("");
  const [message, setMessage] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const router = useRouter();

  async function handleRegister(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (!email || !password || !name) {
      setMessage("Please fill in all fields");
      return;
    }

    if (password.length < 6) {
      setMessage("Password must be at least 6 characters long");
      return;
    }

    setIsLoading(true);
    setMessage("");

    try {
      const result = await authClient.signUp.email({
        email,
        password,
        name,
      });

      if (result.data) {
        setMessage("Registration successful! You can now login.");
        setTimeout(() => {
          router.push("/login");
        }, 2000);
      } else if (result.error) {
        setMessage(result.error.message || "Registration failed");
      }
    } catch (err: any) {
      setMessage(err?.message || "An unexpected error occurred");
    } finally {
      setIsLoading(false);
    }
  }

  return (
    <div className={cn("flex flex-col gap-6", className)} {...props}>
      <Card className="overflow-hidden p-0">
        <CardContent className="grid p-0 md:grid-cols-2">
          <form className="p-6 md:p-8 w-full" onSubmit={handleRegister}>
            <div className="flex flex-col gap-6">
              <div className="flex flex-col items-center text-center">
                <h1 className="text-2xl font-bold">Create your account</h1>
                <p className="text-muted-foreground text-balance">
                  Register for a Starter Inc account
                </p>
              </div>
              <div className="grid gap-3">
                <Label htmlFor="name">Name</Label>
                <Input
                  id="name"
                  type="text"
                  placeholder="Your name"
                  required
                  value={name}
                  onChange={e => setName(e.target.value)}
                  disabled={isLoading}
                />
              </div>
              <div className="grid gap-3">
                <Label htmlFor="email">Email</Label>
                <Input
                  id="email"
                  type="email"
                  placeholder="m@example.com"
                  required
                  value={email}
                  onChange={e => setEmail(e.target.value)}
                  disabled={isLoading}
                />
              </div>
              <div className="grid gap-3">
                <Label htmlFor="password">Password</Label>
                <Input
                  id="password"
                  type="password"
                  placeholder="Password"
                  required
                  value={password}
                  onChange={e => setPassword(e.target.value)}
                  disabled={isLoading}
                />
              </div>
              <Button type="submit" disabled={isLoading}>
                {isLoading ? "Creating Account..." : "Sign Up"}
              </Button>
              {message && (
                <p
                  className={`mt-2 text-sm ${
                    message.includes("successful")
                      ? "text-green-600"
                      : "text-red-600"
                  }`}
                >
                  {message}
                </p>
              )}
              <div className="text-center text-sm">
                Already have an account?{" "}
                <a href="/login" className="underline underline-offset-4">
                  Login here
                </a>
              </div>
            </div>
          </form>
          <div className="bg-muted relative hidden md:block">
            <img
              src="https://ui.shadcn.com/placeholder.svg"
              alt="Image"
              className="absolute inset-0 h-full w-full object-cover dark:brightness-[0.2] dark:grayscale"
            />
          </div>
        </CardContent>
      </Card>
    </div>
  );
}

export default function RegisterPage() {
  return (
    <div className="bg-muted flex min-h-svh flex-col items-center justify-center p-6 md:p-10">
      <div className="w-full max-w-md md:max-w-3xl">
        <RegisterForm />
      </div>
    </div>
  );
}
EOF

# 15. Create App Router home page
rm -rf src/app/page.tsx
cat > "src/app/page.tsx" <<'EOF'
import Link from "next/link";
import { LatestPost } from "~/app/_components/post";
import { api, HydrateClient } from "~/trpc/server";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";

export default async function Home() {
  const hello = await api.post.hello({ text: "from tRPC" });

  void api.post.getLatest.prefetch();

  return (
    <HydrateClient>
      <main className="flex min-h-screen flex-col items-center justify-center bg-gradient-to-b from-[#2e026d] to-[#15162c] text-white">
        <div className="container flex flex-col items-center justify-center gap-12 px-4 py-16">
          <Card className="w-full max-w-2xl bg-white/10 border-none shadow-lg">
            <CardContent className="flex flex-col items-center gap-8 py-10">
              <h1 className="text-5xl font-extrabold tracking-tight sm:text-[5rem] text-white">
                Create <span className="text-[hsl(280,100%,70%)]">T3 - Xode v1.0</span> App
              </h1>
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 md:gap-8 w-full">
                <Link
                  className="flex max-w-xs flex-col gap-4 rounded-xl bg-white/10 p-4 hover:bg-white/20 transition-colors"
                  href="https://create.t3.gg/en/usage/first-steps"
                  target="_blank"
                >
                  <h3 className="text-2xl font-bold text-white">First Steps →</h3>
                  <div className="text-lg text-white/80">
                    Just the basics - Everything you need to know to set up your
                    database and authentication.
                  </div>
                </Link>
                <Link
                  className="flex max-w-xs flex-col gap-4 rounded-xl bg-white/10 p-4 hover:bg-white/20 transition-colors"
                  href="https://create.t3.gg/en/introduction"
                  target="_blank"
                >
                  <h3 className="text-2xl font-bold text-white">Documentation →</h3>
                  <div className="text-lg text-white/80">
                    Learn more about Create T3 App, the libraries it uses, and how
                    to deploy it.
                  </div>
                </Link>
              </div>
              <div className="flex flex-col items-center gap-2 w-full">
                <p className="text-2xl text-white">
                  {hello ? hello.greeting : "Loading tRPC query..."}
                </p>
              </div>
              <div className="flex gap-4 w-full justify-center">
                <Link href="/login" passHref>
                  <Button variant="secondary" className="w-32">
                    Login
                  </Button>
                </Link>
                <Link href="/register" passHref>
                  <Button variant="default" className="w-32">
                    Sign Up
                  </Button>
                </Link>
              </div>
              <div className="w-full">
                <LatestPost />
              </div>
            </CardContent>
          </Card>
        </div>
      </main>
    </HydrateClient>
  );
}
EOF

# 16. Update README.md
cat > "README.md" <<'EOF'
# T3 - Xode v1.0

This is a starter project for a T3 - Xode v1.0 application.

## Features

- Login and Register pages
- Home page

## Installation

1. Clone the repository
2. Run `npm install`
3. Run `npm run dev`


## Usage

1. Run `npm run dev`
2. Open [http://localhost:3000](http://localhost:3000) in your browser


## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details
EOF

echo "✅ Project setup complete! Login page: /login, Register page: /register"
echo "👉 BetterAuth environment variables added to .env"
echo "👉 Remember to change BETTER_AUTH_SECRET in production!"
echo "👉 Update your PostgreSQL DATABASE_URL in .env if needed"
