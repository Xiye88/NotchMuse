# 官网安全响应头补齐

日期：2026-11-18。已在Cloudflare部署并生效。

- 规则：`NotchMuse security response headers`。
- 类型：响应标头转换规则；匹配notchmuse.com区域所有传入请求，使用“设置静态”。
- Rule ID：`425c18cfabe0421aa87434365e28d389`。

| 响应头 | 值 |
| --- | --- |
| Strict-Transport-Security | `max-age=31536000; includeSubDomains` |
| X-Content-Type-Options | `nosniff` |
| X-Frame-Options | `SAMEORIGIN` |
| Referrer-Policy | `strict-origin-when-cross-origin` |
| Permissions-Policy | `camera=(), microphone=(), geolocation=()` |
| Cross-Origin-Opener-Policy | `same-origin` |
| Cross-Origin-Resource-Policy | `same-origin` |

验证：apex/www首页7项精确匹配；原CSP不变。浏览器首页正常加载4个样式表、11张图片；PVUV运行时正常，上报`/in`返回204。未发现CORP阻断，因此保留全部7项。

未修改App、网站代码、DNS或正式更新源。若需回退，可在Cloudflare禁用上述单条规则。
