import type { SupportLocale } from './support';

const en = {
  eyebrow: 'Contact Serlink support', topic: 'What can we help with?',
  topics: { problem: 'Report a problem', feature: 'Suggest a feature', question: 'Ask a question', privacy: 'Privacy request' },
  prompts: {
    problem: 'What were you doing? What happened, and what did you expect? Include the exact error if available.',
    feature: 'What would you like to do, and how would this help your workflow?',
    question: 'Tell us what you would like to know about Serlink.',
    privacy: 'Describe your privacy question or request without including sensitive documents.'
  },
  email: 'Your email', subject: 'Subject', subjectHint: 'A short summary', details: 'How can we help?',
  privacyHint: 'Do not include passwords, private keys, recovery keys, MCP tokens, private terminal output, or Apple ID credentials.',
  device: 'App and device details', optional: 'Optional', appVersion: 'Serlink version', osVersion: 'Operating system version', deviceModel: 'Device model',
  appHint: 'e.g. 0.1.3', macosHint: 'e.g. iOS 26', formatHint: 'e.g. iPhone, iPad Pro, Mac',
  verified: 'Security check complete.', verifying: 'Complete the security check to send your request.', sending: 'Sending…', send: 'Send request', retry: 'Retry verification',
  consent: 'Your email and message will be sent to our OnFire support system to handle your request.', privacyLink: 'Privacy policy',
  success: 'Request received', successDetail: 'Your request is in the Serlink support queue. Keep this reference when you contact us again.',
  home: 'Back to Serlink', noScript: 'Enable JavaScript to verify and send a request. The troubleshooting guides below remain available without JavaScript.',
  errors: {
    method: 'Reload the support page and try again.', origin: 'Please submit from serlink.alkinum.com.',
    media: 'The request format is invalid. Reload the support page.', unavailable: 'Support is temporarily unavailable. Keep a copy of your message and try again later.',
    invalid: 'Check your email, subject, and message, then try again.', rate_limit: 'Too many attempts. Please wait a minute before trying again.',
    verification: 'The security check expired or failed. Please complete it again.',
    form: 'The support form has changed. Keep a copy of your message, then reload the page.',
    uncertain: 'We could not confirm whether your request was received. Keep a copy of your message and wait before sending another request to avoid duplicates.',
    captcha: 'The security check could not load. Retry verification or try again later. The troubleshooting guides below may help.', timeout: 'The security check timed out. Please retry.'
  }
};
type Copy = typeof en;
export const supportCopy: Record<SupportLocale, Copy> = {
  en,
  ja: {
  "eyebrow": "Serlinkサポートへのお問い合わせ",
  "topic": "お問い合わせの種類",
  "topics": {
    "problem": "問題の報告",
    "feature": "機能の提案",
    "question": "使い方の質問",
    "privacy": "プライバシーに関する依頼"
  },
  "prompts": {
    "problem": "操作手順、実際の結果、期待した結果を説明してください。エラーがあれば正確な文面を記載してください。",
    "feature": "実現したい操作と、その機能が役立つ理由を説明してください。",
    "question": "Serlinkの使い方について知りたいことをお知らせください。",
    "privacy": "機密文書を含めず、プライバシーに関する質問や依頼を説明してください。"
  },
  "email": "返信先メールアドレス",
  "subject": "件名",
  "subjectHint": "内容の短い要約",
  "details": "詳しい内容",
  "privacyHint": "パスワード、秘密鍵、復旧キー、MCPトークン、個人の端末出力やApple IDの認証情報を含めないでください。",
  "device": "アプリと端末の情報",
  "optional": "任意",
  "appVersion": "Serlinkのバージョン",
  "osVersion": "OSのバージョン",
  "deviceModel": "端末の種類",
  "appHint": "例：0.1.0",
  "macosHint": "例：macOS、iOS、Windows",
  "formatHint": "例：Mac、iPhone、PC",
  "verified": "セキュリティ確認が完了しました。",
  "verifying": "セキュリティ確認を完了すると送信できます。",
  "sending": "送信中…",
  "send": "問い合わせを送信",
  "retry": "もう一度確認",
  "consent": "メールアドレスと内容は、ご依頼に対応するためOnFireサポートシステムに送信されます。",
  "privacyLink": "プライバシーポリシー",
  "success": "お問い合わせを受け付けました",
  "successDetail": "Serlinkサポートに送信されました。追加のお問い合わせのため、受付番号を保存してください。",
  "home": "Serlinkのホームに戻る",
  "noScript": "JavaScriptを有効にして、セキュリティ確認を完了し、送信してください。下のガイドはJavaScriptなしでも閲覧できます。",
  "errors": {
    "method": "サポートページを再読み込みしてお試しください。",
    "origin": "serlink.alkinum.comから送信してください。",
    "media": "送信形式が無効です。ページを再読み込みしてください。",
    "unavailable": "現在サポートを利用できません。内容を保存し、時間をおいて再度お試しください。",
    "invalid": "メールアドレス、件名、内容を確認してください。",
    "rate_limit": "試行回数が多すぎます。1分後にお試しください。",
    "verification": "セキュリティ確認の期限が切れたか、確認に失敗しました。もう一度確認してください。",
    "form": "フォームが更新されました。内容を保存してからページを再読み込みしてください。",
    "uncertain": "受信を確認できませんでした。重複送信を避けるため内容を保存し、時間をおいてから再度送信してください。",
    "captcha": "セキュリティ確認を読み込めませんでした。再確認するか、時間をおいてお試しください。",
    "timeout": "セキュリティ確認がタイムアウトしました。もう一度お試しください。"
  }
},
  zh: {
    eyebrow: '联系 Serlink 支持', topic: '你需要哪方面的帮助？',
    topics: { problem: '问题反馈', feature: '功能建议', question: '使用咨询', privacy: '隐私请求' },
    prompts: {
      problem: '请描述操作步骤、实际结果与预期结果。如果有错误提示，请提供完整文字。',
      feature: '你希望完成什么操作？这项功能会如何改善你的使用体验？',
      question: '请告诉我们你想了解的 Serlink 使用问题。',
      privacy: '请描述你的隐私问题或请求，不要附带敏感文档。'
    },
    email: '你的邮箱', subject: '主题', subjectHint: '用一句话概括', details: '详细描述',
    privacyHint: '请勿包含密码、私钥、恢复密钥、MCP 令牌、私人终端输出或 Apple ID 登录凭据。',
    device: '应用与设备信息', optional: '选填', appVersion: 'Serlink 版本', osVersion: '系统版本', deviceModel: '设备型号',
    appHint: '例如 0.1.3', macosHint: '例如 iOS 26', formatHint: '例如 iPhone、iPad Pro、Mac',
    verified: '安全验证已完成。', verifying: '完成安全验证后即可发送。', sending: '正在发送…', send: '发送请求', retry: '重新验证',
    consent: '你的邮箱与消息将提交至我们的 OnFire 支持系统，用于处理本次请求。', privacyLink: '隐私政策',
    success: '请求已收到', successDetail: '你的请求已进入 Serlink 支持队列。再次联系我们时，请提供以下工单编号。',
    home: '返回 Serlink 首页', noScript: '请启用 JavaScript 以完成安全验证并发送请求。下方的故障排查指南无需 JavaScript 即可阅读。',
    errors: {
      method: '请重新加载支持页面后再试。', origin: '请从 serlink.alkinum.com 提交。',
      media: '请求格式有误，请重新加载支持页面。', unavailable: '支持服务暂时不可用，请先保存消息副本，稍后再试。',
      invalid: '请检查邮箱、主题与详细描述后再试。', rate_limit: '尝试次数过多，请等待一分钟后再试。',
      verification: '安全验证已过期或未通过，请重新验证。',
      form: '支持表单已更新，请先保存消息副本，再重新加载页面。',
      uncertain: '暂时无法确认请求是否已收到。为避免重复提交，请保存消息副本，等待一段时间后再发送其他请求。',
      captcha: '安全验证未能加载，请重新验证或稍后再试。也可以先查看下方的故障排查指南。', timeout: '安全验证超时，请重试。'
    }
  }
};
