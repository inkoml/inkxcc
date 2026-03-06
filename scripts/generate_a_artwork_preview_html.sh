#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

OUT_HTML="static/pdf/a-artwork-preview.html"
mkdir -p "$(dirname "$OUT_HTML")" "static/downloads"

strip_quotes() {
  local s="$1"
  s="${s%\"}"
  s="${s#\"}"
  s="${s%\'}"
  s="${s#\'}"
  printf '%s' "$s"
}

escape_html() {
  printf '%s' "$1" \
    | sed -e 's/&/\&amp;/g' \
          -e 's/</\&lt;/g' \
          -e 's/>/\&gt;/g' \
          -e 's/"/\&quot;/g'
}

front_matter() {
  awk '
    BEGIN { infm=0 }
    /^---[[:space:]]*$/ {
      if (infm == 0) { infm=1; next }
      else { exit }
    }
    infm==1 { print }
  ' "$1"
}

body_markdown() {
  awk '
    BEGIN { splitCount=0 }
    /^---[[:space:]]*$/ { splitCount++; next }
    splitCount >= 2 { print }
  ' "$1"
}

fm_value() {
  local fm="$1"
  local key="$2"
  printf '%s\n' "$fm" | sed -n "s/^${key}:[[:space:]]*//p" | head -n1
}

extract_image_urls() {
  perl -CS -Mutf8 -ne '
    while (/!\[[^\]]*\]\((https?:\/\/[^)\s]+)\)/g) { print "$1\n"; }
    while (/<img[^>]*src=["\047]?([^"\047 >]+)["\047]?/g) { print "$1\n"; }
  ' "$1"
}

clean_text_stream() {
  perl -CS -Mutf8 -0777 -pe '
    s/\r/\n/g;
    s/\{\{<[^>]*>\}\}//g;
    s/\{\{<\s*\/[^>]*>\}\}//g;
    s/\{\{%\s*[^%]*%\}\}//g;
    s/\{\{%\s*\/[^%]*%\}\}//g;
    s/<script\b[^>]*>.*?<\/script>/ /gis;
    s/<style\b[^>]*>.*?<\/style>/ /gis;
    s/<iframe\b[^>]*>.*?<\/iframe>/ /gis;
    s/<video\b[^>]*>.*?<\/video>/ /gis;
    s/<source\b[^>]*>/ /gis;
    s/!\[[^\]]*\]\(([^)]+)\)/ /g;
    s/\[([^\]]+)\]\(([^)]+)\)/$1/g;
    s/<[^>]+>/ /g;
    s/^\s{0,3}#{1,6}\s*//mg;
    s/^\s*[-*+]\s+//mg;
    s/^\s*\d+\.\s+//mg;
    s/`{1,3}[^`]*`{1,3}/ /g;
    s/[⬆↑]\s*点击查看视频\s*[⬆↑]?/ /g;
    s/点击查看视频/ /g;
    s/观看视频/ /g;
    s/[⬆↑]+/ /g;
    s/&nbsp;/ /g;
    s/&amp;/&/g;
    s/&lt;/</g;
    s/&gt;/>/g;
    s/\s+/ /g;
    s/^\s+|\s+$//g;
  '
}

make_summary_300() {
  perl -CS -Mutf8 -e '
    use strict;
    use warnings;
    my $t = do { local $/; <STDIN> };
    $t =~ s/\s+/ /g;
    $t =~ s/^\s+|\s+$//g;

    my @sent = split /(?<=[。！？!?；;])/u, $t;
    my $out = q{};
    for my $s (@sent) {
      $s =~ s/^\s+|\s+$//g;
      next if length($s) < 6;
      $out .= $s;
      last if length($out) >= 260;
    }
    if (length($out) < 80) {
      $out = substr($t, 0, 220);
    }
    $out =~ s/^\s+|\s+$//g;
    if (length($out) > 280) {
      $out = substr($out, 0, 280);
    }
    print $out;
  '
}

make_detail_excerpt() {
  perl -CS -Mutf8 -e '
    use strict;
    use warnings;
    my $t = do { local $/; <STDIN> };
    $t =~ s/\s+/ /g;
    $t =~ s/^\s+|\s+$//g;

    my @sent = grep { length($_) >= 8 } split /(?<=[。！？!?；;])/u, $t;
    my @out = ();
    my $buf = q{};
    for my $s (@sent) {
      $s =~ s/^\s+|\s+$//g;
      next if $s eq q{};
      if (length($buf) + length($s) > 170) {
        push @out, $buf if $buf ne q{};
        $buf = $s;
      } else {
        $buf .= $s;
      }
      last if scalar(@out) >= 3;
    }
    push @out, $buf if $buf ne q{} && scalar(@out) < 3;

    if (!@out) {
      my $tmp = substr($t, 0, 360);
      while (length($tmp) > 0 && scalar(@out) < 3) {
        push @out, substr($tmp, 0, 160, q{});
      }
    }
    print join("\n", @out);
  '
}

tmp_dir="$(mktemp -d)"
records="${tmp_dir}/records.tsv"
trap 'rm -rf "$tmp_dir"' EXIT

count=0
while IFS= read -r file; do
  fm="$(front_matter "$file")"
  draft="$(strip_quotes "$(fm_value "$fm" "draft")")"
  if [[ "$draft" != "false" ]]; then
    continue
  fi

  title="$(strip_quotes "$(fm_value "$fm" "title")")"
  slug="$(strip_quotes "$(fm_value "$fm" "slug")")"
  summary="$(strip_quotes "$(fm_value "$fm" "summary")")"
  description="$(strip_quotes "$(fm_value "$fm" "description")")"
  cover="$(strip_quotes "$(fm_value "$fm" "image")")"
  code_name="$(basename "$file" .md)"

  body_md="$(body_markdown "$file")"
  body_clean="$(printf '%s' "$body_md" | clean_text_stream)"
  summary_source="$body_clean"
  body_chars="$(printf '%s' "$summary_source" | wc -m | tr -d ' ')"
  if [[ "$body_chars" -lt 260 ]]; then
    summary_source="$(printf '%s %s %s' "$summary" "$description" "$body_clean" | clean_text_stream)"
  fi

  summary_text="$(printf '%s' "$summary_source" | make_summary_300 | tr '\t' ' ')"
  detail_text="$(printf '%s' "$body_clean" | make_detail_excerpt | tr '\t' ' ')"

  summary_file="${tmp_dir}/sum_${count}.txt"
  detail_file="${tmp_dir}/detail_${count}.txt"
  printf '%s' "$summary_text" > "$summary_file"
  printf '%s' "$detail_text" > "$detail_file"

  image_list_file="${tmp_dir}/images_${count}.txt"
  {
    if [[ -n "${cover// }" ]]; then
      printf '%s\n' "$cover"
    fi
    extract_image_urls "$file"
  } | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | awk 'NF && !seen[$0]++' | head -n 8 > "$image_list_file"

  imgs=()
  while IFS= read -r img_line || [[ -n "$img_line" ]]; do
    imgs+=("$img_line")
  done < "$image_list_file"
  img1="${imgs[0]:-}"
  img2="${imgs[1]:-}"
  img3="${imgs[2]:-}"
  img4="${imgs[3]:-}"
  img5="${imgs[4]:-}"
  img6="${imgs[5]:-}"
  img7="${imgs[6]:-}"
  img8="${imgs[7]:-}"

  if [[ -z "$img2" ]]; then img2="$img1"; fi
  if [[ -z "$img3" ]]; then img3="$img1"; fi
  if [[ -z "$img4" ]]; then img4="$img2"; fi
  if [[ -z "$img5" ]]; then img5="$img1"; fi
  if [[ -z "$img6" ]]; then img6="$img2"; fi
  if [[ -z "$img7" ]]; then img7="$img3"; fi
  if [[ -z "$img8" ]]; then img8="$img4"; fi

  count=$((count + 1))
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$count" "$code_name" "$title" "$slug" "$img1" "$img2" "$img3" "$img4" "$img5" "$img6" "$img7" "$img8" "$summary_file" "$detail_file" >> "$records"
done < <(find content/artwork -maxdepth 1 -type f -name '*.md' | sort -V)

cat > "$OUT_HTML" <<'HTML_HEAD'
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>In_K 作品档案（16:9）</title>
  <style>
    @page { size: 320mm 180mm; margin: 0; }
    * { box-sizing: border-box; }
    html, body {
      margin: 0;
      padding: 0;
      background: #000000;
      font-family: "Noto Sans SC", "PingFang SC", "Microsoft YaHei", sans-serif;
      color: #f5f7fa;
    }
    .page {
      width: 320mm;
      height: 180mm;
      margin: 0 auto;
      background: #050506;
      page-break-after: always;
      overflow: hidden;
      position: relative;
    }
    .page:last-child { page-break-after: auto; }
    .pad { padding: 12mm 13mm; }
    .cover {
      background:
        radial-gradient(circle at 15% 18%, rgba(66, 133, 244, 0.18), transparent 45%),
        radial-gradient(circle at 86% 72%, rgba(239, 68, 68, 0.16), transparent 46%),
        radial-gradient(circle at 58% 36%, rgba(255, 255, 255, 0.06), transparent 36%),
        #020202;
      color: #ffffff;
    }
    .cover .kicker { font-size: 12px; letter-spacing: 0.18em; text-transform: uppercase; opacity: 0.9; color: #d1d5db; }
    .cover h1 { margin: 8mm 0 4mm; font-size: 56px; letter-spacing: -0.02em; line-height: 1.06; }
    .cover p { margin: 0 0 4mm; font-size: 17px; max-width: 70%; line-height: 1.6; color: #e5e7eb; }
    .cover .meta { position: absolute; left: 13mm; bottom: 11mm; font-size: 12px; color: #9ca3af; }
    .section-kicker { margin: 0 0 3mm; font-size: 12px; letter-spacing: 0.16em; text-transform: uppercase; color: #9ca3af; }
    .section-title { margin: 0 0 6mm; font-size: 34px; letter-spacing: -0.01em; color: #ffffff; }
    .split-two {
      display: grid;
      grid-template-columns: 1.05fr 1fr;
      gap: 8mm;
      height: 100%;
      align-items: start;
    }
    .panel {
      background: #0e0e11;
      border: 1px solid #24262c;
      border-radius: 10px;
      padding: 5mm 5mm 4mm;
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.35);
    }
    .panel p { margin: 0 0 2.2mm; font-size: 15px; line-height: 1.82; color: #f3f4f6; text-align: justify; }
    .panel p:last-child { margin-bottom: 0; }
    .panel h3 {
      margin: 0 0 2.2mm;
      font-size: 13px;
      color: #c7ccd6;
      letter-spacing: 0.08em;
      text-transform: uppercase;
    }
    .chip-wrap { display: flex; flex-wrap: wrap; gap: 2.5mm; margin-bottom: 4mm; }
    .chip {
      border: 1px solid #3a3f49;
      color: #e5e7eb;
      border-radius: 999px;
      padding: 1.6mm 3mm;
      font-size: 12px;
      background: #111318;
    }
    .intro-img, .method-img {
      width: 100%;
      height: 144mm;
      object-fit: cover;
      border-radius: 10px;
      border: 1px solid #2d313a;
      background: #0f1115;
    }
    .index h2 { margin: 0 0 6mm; font-size: 34px; letter-spacing: -0.01em; color: #ffffff; }
    .index ul { list-style: none; margin: 0; padding: 0; columns: 2; column-gap: 12mm; }
    .index li { break-inside: avoid; display: grid; grid-template-columns: 14mm 1fr; gap: 3mm; font-size: 14px; padding: 1.8mm 0; border-bottom: 1px dashed #343845; color: #f3f4f6; }
    .idx { color: #a1a1aa; font-variant-numeric: tabular-nums; }
    .work-title-page {
      background:
        radial-gradient(circle at 76% 22%, rgba(59, 130, 246, 0.14), transparent 40%),
        radial-gradient(circle at 25% 75%, rgba(239, 68, 68, 0.14), transparent 45%),
        #07070a;
    }
    .work-title-page h2 {
      margin: 12mm 0 3mm;
      font-size: 54px;
      letter-spacing: -0.02em;
      color: #ffffff;
    }
    .work-title-page p {
      margin: 0;
      max-width: 60%;
      color: #d1d5db;
      font-size: 16px;
      line-height: 1.7;
    }
    .work-page {
      display: flex;
      flex-direction: column;
      height: 100%;
    }
    .work-meta {
      background: #0e0e11;
      border: 1px solid #24262c;
      border-radius: 10px;
      padding: 4mm 4.4mm 3.4mm;
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.35);
      margin-bottom: 4mm;
      min-height: 38mm;
    }
    .work-meta .code {
      margin: 0 0 1.3mm;
      font-size: 11px;
      letter-spacing: 0.14em;
      text-transform: uppercase;
      color: #9ca3af;
    }
    .work-meta h3 {
      margin: 0 0 2.1mm;
      font-size: 28px;
      line-height: 1.14;
      letter-spacing: -0.01em;
      color: #ffffff;
    }
    .work-meta p {
      margin: 0 0 1.6mm;
      font-size: 13px;
      line-height: 1.6;
      color: #f3f4f6;
      text-align: justify;
    }
    .work-meta p:last-child { margin-bottom: 0; }
    .work-link {
      font-size: 12px;
      color: #9ca3af;
      word-break: break-all;
    }
    .work-link a { color: #93c5fd; text-decoration: none; }
    .img-grid-4 {
      flex: 1;
      min-height: 0;
      display: grid;
      grid-template-columns: 1fr 1fr;
      grid-template-rows: 1fr 1fr;
      gap: 4mm;
    }
    .img-card {
      width: 100%;
      height: 100%;
      object-fit: cover;
      border-radius: 8px;
      border: 1px solid #2d313a;
      background: #101217;
    }
    .placeholder {
      width: 100%;
      height: 100%;
      border-radius: 8px;
      border: 1px dashed #3b3f48;
      background: repeating-linear-gradient(-45deg, #0d0f14, #0d0f14 10px, #11141b 10px, #11141b 20px);
      color: #9ca3af;
      font-size: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .back-cover {
      background:
        radial-gradient(circle at 22% 25%, rgba(59, 130, 246, 0.14), transparent 45%),
        radial-gradient(circle at 78% 70%, rgba(239, 68, 68, 0.15), transparent 46%),
        #030303;
    }
    .back-grid {
      display: grid;
      grid-template-columns: 1.2fr 1fr;
      gap: 10mm;
      height: 100%;
    }
    .contact h2 {
      margin: 0 0 4mm;
      font-size: 42px;
      letter-spacing: -0.02em;
      color: #ffffff;
    }
    .contact p {
      margin: 0 0 3.2mm;
      font-size: 16px;
      color: #e5e7eb;
      line-height: 1.7;
    }
    .contact a {
      color: #bfdbfe;
      text-decoration: none;
      word-break: break-all;
    }
    .contact .label {
      color: #9ca3af;
      font-size: 12px;
      letter-spacing: 0.1em;
      text-transform: uppercase;
      margin-bottom: 2mm;
    }
    .qr-wrap {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 4mm;
      align-content: start;
    }
    .qr-card {
      background: #0f1014;
      border: 1px solid #2e3340;
      border-radius: 10px;
      padding: 3.2mm;
      text-align: center;
    }
    .qr-card img {
      width: 100%;
      height: auto;
      border-radius: 8px;
      border: 1px solid #3a3f49;
      background: #ffffff;
    }
    .qr-card p {
      margin: 2mm 0 0;
      font-size: 12px;
      color: #d1d5db;
    }
  </style>
</head>
<body>
HTML_HEAD

today="$(date '+%Y-%m-%d')"
intro_image="https://r2.inkx.cc/ink.%202019..jpg"
method_image="https://r2.inkx.cc/20250619035059795.png"
qr_site="/pdf/qr-site.png"
qr_bili="/pdf/qr-bili.png"
intro_image_esc="$(escape_html "$intro_image")"
method_image_esc="$(escape_html "$method_image")"
qr_site_esc="$(escape_html "$qr_site")"
qr_bili_esc="$(escape_html "$qr_bili")"

cat >> "$OUT_HTML" <<EOF
  <section class="page pad">
    <p class="section-kicker">Artist Profile</p>
    <h2 class="section-title">艺术家简介</h2>
    <div class="split-two">
      <div class="panel">
        <h3>In_K / ink / vjink</h3>
        <p>新媒体艺术家毕振宇（In_K）长期在艺术、技术与现场之间工作，以算法编程驱动的生成式影像为核心路径。其创作强调“系统生成”而非一次性输出，关注图像如何在规则、噪声与时间中持续演化。</p>
        <p>实践范围覆盖动态影像、互动装置、实时视觉系统与 AudioVisual 表演，并持续探索人工智能与自动化系统对感知结构和审美机制的重构。作品在展览空间、公共场域与舞台现场中形成多种实例化版本。</p>
      </div>
      <div>
        <img class="intro-img" src="${intro_image_esc}" alt="In_K" />
      </div>
    </div>
  </section>

  <section class="page pad">
    <p class="section-kicker">Method & Media</p>
    <h2 class="section-title">创作方法与媒介</h2>
    <div class="split-two">
      <div class="panel">
        <h3>方法论</h3>
        <div class="chip-wrap">
          <span class="chip">系统生成</span>
          <span class="chip">实时渲染</span>
          <span class="chip">交互编程</span>
          <span class="chip">AIGC 视觉实验</span>
          <span class="chip">空间叙事</span>
          <span class="chip">音视耦合</span>
        </div>
        <h3>媒介与实践场景</h3>
        <p>媒介侧覆盖生成式影像、互动装置、舞台视觉、沉浸式展示与跨屏联动系统。方法上通过同一算法框架处理不同主题变量，在概念层维持统一逻辑、在形式层产生差异化输出。</p>
        <h3>工具栈（常用）</h3>
        <div class="chip-wrap">
          <span class="chip">vvvv</span>
          <span class="chip">Unreal Engine</span>
          <span class="chip">Blender</span>
          <span class="chip">Stable Diffusion</span>
        </div>
      </div>
      <div>
        <img class="method-img" src="${method_image_esc}" alt="Method and Media" />
      </div>
    </div>
  </section>

  <section class="page index pad">
    <p class="section-kicker">Table of Contents</p>
    <h2>作品目录（按编号）</h2>
    <ul>
EOF

while IFS=$'\t' read -r idx code_name title slug img1 img2 img3 img4 img5 img6 img7 img8 summary_file detail_file; do
  idx_esc="$(printf '%02d' "$idx")"
  code_esc="$(escape_html "$code_name")"
  title_esc="$(escape_html "$title")"
  printf '      <li><span class="idx">%s</span><span>%s｜%s</span></li>\n' "$idx_esc" "$code_esc" "$title_esc" >> "$OUT_HTML"
done < "$records"

cat >> "$OUT_HTML" <<'HTML_INDEX_END'
    </ul>
  </section>

  <section class="page work-title-page pad">
    <p class="section-kicker">Works</p>
    <h2>作品</h2>
    <p>以下作品按 md 文件编号顺序编排。每个作品采用双页结构，每页均为 2x2 图片网格；单个作品共 8 张图。</p>
  </section>
HTML_INDEX_END

while IFS=$'\t' read -r idx code_name title slug img1 img2 img3 img4 img5 img6 img7 img8 summary_file detail_file; do
  idx_esc="$(printf '%02d' "$idx")"
  code_esc="$(escape_html "$code_name")"
  title_esc="$(escape_html "$title")"
  summary_esc="$(escape_html "$(cat "$summary_file")")"
  detail_joined="$(tr '\n' ' ' < "$detail_file" | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')"
  detail_esc="$(escape_html "$detail_joined")"
  permalink="https://www.inkx.cc/artwork/${slug}/"
  link_esc="$(escape_html "$permalink")"

  img1_esc="$(escape_html "$img1")"
  img2_esc="$(escape_html "$img2")"
  img3_esc="$(escape_html "$img3")"
  img4_esc="$(escape_html "$img4")"
  img5_esc="$(escape_html "$img5")"
  img6_esc="$(escape_html "$img6")"
  img7_esc="$(escape_html "$img7")"
  img8_esc="$(escape_html "$img8")"

  cat >> "$OUT_HTML" <<EOF
  <section class="page pad">
    <div class="work-page">
      <div class="work-meta">
        <p class="code">Artwork ${idx_esc} · ${code_esc}</p>
        <h3>${title_esc}</h3>
        <p>作品介绍：${summary_esc}</p>
        <p class="work-link">在线页面：<a href="${link_esc}">${link_esc}</a></p>
      </div>
      <div class="img-grid-4">
EOF

  if [[ -n "${img1// }" ]]; then
    printf '        <img class="img-card" src="%s" alt="%s" />\n' "$img1_esc" "$title_esc" >> "$OUT_HTML"
  else
    printf '        <div class="placeholder">No Image</div>\n' >> "$OUT_HTML"
  fi

  if [[ -n "${img2// }" ]]; then
    printf '        <img class="img-card" src="%s" alt="%s" />\n' "$img2_esc" "$title_esc" >> "$OUT_HTML"
  else
    printf '        <div class="placeholder">No Image</div>\n' >> "$OUT_HTML"
  fi

  if [[ -n "${img3// }" ]]; then
    printf '        <img class="img-card" src="%s" alt="%s" />\n' "$img3_esc" "$title_esc" >> "$OUT_HTML"
  else
    printf '        <div class="placeholder">No Image</div>\n' >> "$OUT_HTML"
  fi

  if [[ -n "${img4// }" ]]; then
    printf '        <img class="img-card" src="%s" alt="%s" />\n' "$img4_esc" "$title_esc" >> "$OUT_HTML"
  else
    printf '        <div class="placeholder">No Image</div>\n' >> "$OUT_HTML"
  fi

  cat >> "$OUT_HTML" <<'HTML_WORK_PAGE_1_END'
      </div>
    </div>
  </section>
HTML_WORK_PAGE_1_END

  cat >> "$OUT_HTML" <<EOF
  <section class="page pad">
    <div class="work-page">
      <div class="work-meta">
        <p class="code">Artwork ${idx_esc} · ${code_esc}</p>
        <h3>${title_esc}</h3>
        <p>补充介绍：${detail_esc}</p>
      </div>
      <div class="img-grid-4">
EOF

  if [[ -n "${img5// }" ]]; then
    printf '        <img class="img-card" src="%s" alt="%s" />\n' "$img5_esc" "$title_esc" >> "$OUT_HTML"
  else
    printf '        <div class="placeholder">No Image</div>\n' >> "$OUT_HTML"
  fi

  if [[ -n "${img6// }" ]]; then
    printf '        <img class="img-card" src="%s" alt="%s" />\n' "$img6_esc" "$title_esc" >> "$OUT_HTML"
  else
    printf '        <div class="placeholder">No Image</div>\n' >> "$OUT_HTML"
  fi

  if [[ -n "${img7// }" ]]; then
    printf '        <img class="img-card" src="%s" alt="%s" />\n' "$img7_esc" "$title_esc" >> "$OUT_HTML"
  else
    printf '        <div class="placeholder">No Image</div>\n' >> "$OUT_HTML"
  fi

  if [[ -n "${img8// }" ]]; then
    printf '        <img class="img-card" src="%s" alt="%s" />\n' "$img8_esc" "$title_esc" >> "$OUT_HTML"
  else
    printf '        <div class="placeholder">No Image</div>\n' >> "$OUT_HTML"
  fi

  cat >> "$OUT_HTML" <<'HTML_WORK_PAGE_2_END'
      </div>
    </div>
  </section>
HTML_WORK_PAGE_2_END
done < "$records"

cat >> "$OUT_HTML" <<EOF
  <section class="page back-cover pad">
    <div class="back-grid">
      <div class="contact">
        <p class="label">封底</p>
        <h2>联系方式</h2>
        <p>工作邮箱：work@inkx.cc</p>
        <p>WeChat：inkoml</p>
        <p>网站：<a href="https://www.inkx.cc/">https://www.inkx.cc/</a></p>
        <p>Bilibili：<a href="https://space.bilibili.com/10830102">https://space.bilibili.com/10830102</a></p>
      </div>
      <div class="qr-wrap">
        <div class="qr-card">
          <img src="${qr_site_esc}" alt="网站二维码" />
          <p>网站二维码</p>
        </div>
        <div class="qr-card">
          <img src="${qr_bili_esc}" alt="Bilibili二维码" />
          <p>Bilibili 二维码</p>
        </div>
      </div>
    </div>
  </section>
EOF

cat >> "$OUT_HTML" <<'HTML_END'
</body>
</html>
HTML_END

echo "Generated: $OUT_HTML"
echo "Items: $count"
