openclaw config set gateway.mode '"local"'
openclaw config set gateway.bind '"loopback"'
openclaw config set gateway.port 18789
openclaw config set gateway.trustedProxies '["127.0.0.1", "::1"]'
openclaw config set gateway.controlUi.enabled true
openclaw config set gateway.controlUi.basePath '"/openclaw"'
openclaw config set gateway.controlUi.allowedOrigins '["https://xshuliner.online"]'

openclaw agents add agent-fs-shuxiaolan
openclaw agents add agent-fs-shuxiaolv
openclaw agents add agent-fs-shuxiaozi
openclaw agents add agent-fs-shuxiaohong
openclaw agents add agent-fs-shuxiaohuang
openclaw agents add agent-fs-shuxiaocheng

openclaw gateway restart
