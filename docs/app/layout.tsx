import { RootProvider } from 'fumadocs-ui/provider/next';
import Script from "next/script";
import './global.css';
import { Inter, Cinzel } from 'next/font/google';

const inter = Inter({
  subsets: ['latin'],
  variable: '--font-inter',
});

const cinzel = Cinzel({
  subsets: ['latin'],
  variable: '--font-cinzel',
});

export default function Layout({ children }: LayoutProps<'/'>) {
  return (
    <html lang="en" className={`${inter.className} ${cinzel.variable} dark`} suppressHydrationWarning>
      <head>
        <Script defer={true} src="https://analytics.romarin.dev/script.js" data-website-id="7881ff0d-d064-4d6f-b791-7337927f33d4"/>
        {process.env.NODE_ENV === "development" && (
            <Script
              src="//unpkg.com/react-grab/dist/index.global.js"
              crossOrigin="anonymous"
              strategy="beforeInteractive"
            />
        )}
      </head>
      <body className="flex flex-col min-h-screen">
        <RootProvider theme={{ enabled: false, defaultTheme: 'dark' }}>{children}</RootProvider>
      </body>
    </html>
  );
}
