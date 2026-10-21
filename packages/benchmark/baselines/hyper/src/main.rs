//! The http_load.dart routes on bare hyper, as a floor for the Dart
//! servers. One tokio runtime over every core, HTTP/1.1 keep-alive.
//!
//!   cargo run --release -- 8090
//!   dart run bin/http_load.dart --targets=hyper=http://127.0.0.1:8090

use std::convert::Infallible;
use std::net::SocketAddr;

use bytes::Bytes;
use http_body_util::Full;
use hyper::body::Incoming;
use hyper::header::{CACHE_CONTROL, CONTENT_TYPE, ETAG};
use hyper::server::conn::http1;
use hyper::service::service_fn;
use hyper::{Request, Response, StatusCode};
use hyper_util::rt::TokioIo;
use tokio::net::TcpListener;

const ETAG_VALUE: &str = "\"relic-browser-1\"";

fn items() -> String {
    let mut out = String::from("[");
    for i in 0..20 {
        if i > 0 {
            out.push(',');
        }
        out.push_str(&format!(
            "{{\"id\":{i},\"name\":\"item {i}\",\"tags\":[\"new\",\"sale\"],\"price\":{}}}",
            100 + i
        ));
    }
    out.push(']');
    out
}

fn header<'a>(req: &'a Request<Incoming>, name: &str) -> Option<&'a str> {
    req.headers().get(name).and_then(|v| v.to_str().ok())
}

fn cookie<'a>(header: Option<&'a str>, name: &str) -> Option<&'a str> {
    let header = header?;
    header.split(';').find_map(|pair| {
        let (k, v) = pair.split_once('=')?;
        (k.trim() == name).then(|| v.trim())
    })
}

fn json_string(value: Option<&str>) -> String {
    match value {
        None => "null".to_string(),
        Some(s) => {
            let mut out = String::with_capacity(s.len() + 2);
            out.push('"');
            for c in s.chars() {
                match c {
                    '"' => out.push_str("\\\""),
                    '\\' => out.push_str("\\\\"),
                    c if (c as u32) < 0x20 => out.push_str(&format!("\\u{:04x}", c as u32)),
                    c => out.push(c),
                }
            }
            out.push('"');
            out
        }
    }
}

fn text(body: String) -> Response<Full<Bytes>> {
    Response::builder()
        .header(CONTENT_TYPE, "text/plain; charset=utf-8")
        .body(Full::new(Bytes::from(body)))
        .unwrap()
}

async fn handle(req: Request<Incoming>, items: &'static str) -> Result<Response<Full<Bytes>>, Infallible> {
    let response = match req.uri().path() {
        "/plaintext" => text("Hello, World!".to_string()),
        "/headers" => {
            let agent = header(&req, "user-agent").unwrap_or("");
            let languages = header(&req, "accept-language")
                .map(|v| v.split(',').count())
                .unwrap_or(0);
            let session = cookie(header(&req, "cookie"), "session");
            text(format!(
                "{} {} {}",
                agent.len(),
                languages,
                session.map(str::len).unwrap_or(0)
            ))
        }
        "/browser" => {
            let host = header(&req, "host");
            let session = cookie(header(&req, "cookie"), "session");
            if header(&req, "if-none-match") == Some(ETAG_VALUE) {
                Response::builder()
                    .status(StatusCode::NOT_MODIFIED)
                    .header(ETAG, ETAG_VALUE)
                    .body(Full::new(Bytes::new()))
                    .unwrap()
            } else {
                let body = format!(
                    "{{\"host\":{},\"session\":{},\"items\":{}}}",
                    json_string(host),
                    json_string(session),
                    items
                );
                Response::builder()
                    .header(CONTENT_TYPE, "application/json; charset=utf-8")
                    .header(ETAG, ETAG_VALUE)
                    .header(CACHE_CONTROL, "private, max-age=60")
                    .body(Full::new(Bytes::from(body)))
                    .unwrap()
            }
        }
        _ => Response::builder()
            .status(StatusCode::NOT_FOUND)
            .body(Full::new(Bytes::new()))
            .unwrap(),
    };
    Ok(response)
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let port: u16 = std::env::args().nth(1).map(|p| p.parse()).transpose()?.unwrap_or(8090);
    let items: &'static str = Box::leak(items().into_boxed_str());
    let addr = SocketAddr::from(([127, 0, 0, 1], port));
    let listener = TcpListener::bind(addr).await?;
    println!("listening on http://{addr}/");
    loop {
        let (stream, _) = listener.accept().await?;
        tokio::spawn(async move {
            let io = TokioIo::new(stream);
            let service = service_fn(move |req| handle(req, items));
            if let Err(err) = http1::Builder::new().serve_connection(io, service).await {
                eprintln!("connection: {err}");
            }
        });
    }
}
