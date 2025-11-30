//
//  ShowNotesView.swift
//  Outcast
//
//  WebView wrapper for rendering HTML show notes
//

import SwiftUI
import WebKit

/// A view that renders HTML show notes with dark theme styling
struct ShowNotesView: UIViewRepresentable {
    let htmlContent: String
    let tintColor: Color
    
    init(htmlContent: String?, tintColor: Color = .white) {
        self.htmlContent = htmlContent ?? ""
        self.tintColor = tintColor
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let styledHTML = wrapHTMLContent(htmlContent)
        webView.loadHTMLString(styledHTML, baseURL: nil)
    }
    
    private func wrapHTMLContent(_ rawHTML: String) -> String {
        let tintHex = UIColor(tintColor).toHexString()
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }
                
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Helvetica Neue', sans-serif;
                    font-size: 16px;
                    line-height: 1.6;
                    color: rgba(255, 255, 255, 0.85);
                    background-color: transparent;
                    padding: 0;
                    margin: 0;
                    word-wrap: break-word;
                    overflow-wrap: break-word;
                }
                
                p {
                    margin-bottom: 16px;
                }
                
                h1, h2, h3, h4, h5, h6 {
                    color: rgba(255, 255, 255, 0.95);
                    margin-top: 20px;
                    margin-bottom: 12px;
                    font-weight: 600;
                }
                
                h1 { font-size: 24px; }
                h2 { font-size: 22px; }
                h3 { font-size: 20px; }
                h4 { font-size: 18px; }
                h5 { font-size: 16px; }
                h6 { font-size: 14px; }
                
                a {
                    color: \(tintHex);
                    text-decoration: none;
                    border-bottom: 1px solid rgba(255, 255, 255, 0.2);
                }
                
                a:active {
                    opacity: 0.6;
                }
                
                ul, ol {
                    margin-left: 20px;
                    margin-bottom: 16px;
                }
                
                li {
                    margin-bottom: 8px;
                }
                
                blockquote {
                    border-left: 3px solid rgba(255, 255, 255, 0.3);
                    padding-left: 16px;
                    margin: 16px 0;
                    color: rgba(255, 255, 255, 0.7);
                    font-style: italic;
                }
                
                code {
                    background-color: rgba(255, 255, 255, 0.1);
                    padding: 2px 6px;
                    border-radius: 4px;
                    font-family: 'SF Mono', 'Monaco', 'Courier New', monospace;
                    font-size: 14px;
                }
                
                pre {
                    background-color: rgba(255, 255, 255, 0.1);
                    padding: 12px;
                    border-radius: 8px;
                    overflow-x: auto;
                    margin-bottom: 16px;
                }
                
                pre code {
                    background-color: transparent;
                    padding: 0;
                }
                
                img {
                    max-width: 100%;
                    height: auto;
                    border-radius: 8px;
                    margin: 16px 0;
                }
                
                hr {
                    border: none;
                    border-top: 1px solid rgba(255, 255, 255, 0.2);
                    margin: 24px 0;
                }
                
                table {
                    width: 100%;
                    border-collapse: collapse;
                    margin-bottom: 16px;
                }
                
                th, td {
                    border: 1px solid rgba(255, 255, 255, 0.2);
                    padding: 8px;
                    text-align: left;
                }
                
                th {
                    background-color: rgba(255, 255, 255, 0.1);
                    font-weight: 600;
                }
            </style>
        </head>
        <body>
            \(rawHTML)
        </body>
        </html>
        """
    }
}

// MARK: - UIColor Extension

extension UIColor {
    convenience init(_ color: Color) {
        let components = color.components()
        self.init(red: components.r, green: components.g, blue: components.b, alpha: components.a)
    }
    
    func toHexString() -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let rgb: Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0
        
        return String(format:"#%06x", rgb)
    }
}

extension Color {
    func components() -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        // Use cgColor directly to avoid circular reference with UIColor extension
        guard let cgColor = cgColor,
              let components = cgColor.components else {
            return (1, 1, 1, 1) // Default to white
        }
        
        let numComponents = cgColor.numberOfComponents
        if numComponents == 2 {
            // Grayscale color
            return (components[0], components[0], components[0], components[1])
        } else if numComponents >= 4 {
            return (components[0], components[1], components[2], components[3])
        }
        
        return (1, 1, 1, 1)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        ShowNotesView(
            htmlContent: """
            <h2>Episode Description</h2>
            <p>This is a <strong>sample episode</strong> description with <em>HTML formatting</em>.</p>
            <p>It includes:</p>
            <ul>
                <li>Bullet points</li>
                <li>Links like <a href="https://example.com">this one</a></li>
                <li>And other HTML elements</li>
            </ul>
            <blockquote>Here's a quote from the episode.</blockquote>
            """,
            tintColor: .blue
        )
        .padding()
    }
}
