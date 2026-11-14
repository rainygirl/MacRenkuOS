# MacRenkuOS

[English](README.md)

[RenkuOS](https://github.com/rainygirl/renkuos-arm64)를 Apple Silicon에서,
터미널에서, 명령어 한 줄로 실행합니다.

## 설치

```sh
curl -fsSL https://raw.githubusercontent.com/rainygirl/MacRenkuOS/main/macrenkuos.sh | bash
```

Homebrew와 QEMU가 없으면 먼저 물어보고 설치하고, 처음 실행할 때 라이브
ISO를 받은 뒤 바로 전체화면 RenkuOS 데스크탑으로 부팅합니다. `.app`도
`.dmg`도, Gatekeeper/노터라이제이션 절차도 없습니다. 실행하면 `renkuos`
명령어도 함께 설치되므로, 다음부터는 이렇게만 실행하면 됩니다:

```sh
renkuos
```

## 요구 사항

- Apple Silicon Mac, macOS 13 이상.
- 처음 실행할 때 인터넷 연결 필요 (Homebrew/QEMU 설치, 런처 파일 가져오기,
  라이브 ISO(~450MB) 다운로드용).

## 사용하기

실행할 때마다 같은 라이브 미디어로 부팅합니다; 설치할 것도 거쳐야 할 화면도
없습니다. 쓰기 내용은 ISO 옆의 qcow2 오버레이에 계속 남습니다
(`~/Library/Application Support/Renku/renku-arm64-live-overlay.qcow2`를
지우면 깨끗한 라이브 세션으로 초기화됩니다) -- 그래서 설치된 디스크와
마찬가지로, 창을 닫거나 QEMU를 종료하기 전에 게스트를 제대로 종료해야
합니다(Deskbar > Shut Down).
