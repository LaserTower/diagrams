#!/usr/bin/env bash
set -euo pipefail

API_TOKEN="${1}"
API_URL="https://anythingllm.lasertower.ru/api/v1"

if [ -z "$API_TOKEN" ]; then
  echo "Ошибка: API_TOKEN не передан!" >&2
  exit 1
fi

for file in $(git diff --name-only HEAD~1 HEAD); do
  filename=$(basename "$file")
  workplace=$(basename $(dirname "$file"))

  echo "=== Обработка файла: $file (workspace: $workplace) ==="

  # Получаем информацию о workspace
  workspace_json=$(curl -s "$API_URL/workspace/$workplace" \
    -H "Authorization: Bearer ${API_TOKEN}" \
    --fail-with-body)

  # Ищем существующий файл в workspace
  delete_file=$(echo "$workspace_json" | jq -r --arg filename "$filename" \
    '.workspace[0].documents[] | select(.metadata | fromjson.title == $filename).filename')

  # Удаляем старый файл если существует
  if [ -n "$delete_file" ]; then
    echo "Удаляем существующий файл: $delete_file"

    curl -s -X POST "$API_URL/system/remove-documents" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer ${API_TOKEN}" \
      -d "{\"names\": [\"$delete_file\"]}" > /dev/null 2>&1

    echo "Удаляем embedding: $delete_file"
    curl -s -X POST "$API_URL/workspace/$workplace/update-embeddings" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer ${API_TOKEN}" \
      -d "{\"deletes\": [\"$delete_file\"]}" > /dev/null 2>&1
  fi

  # Загружаем новый файл
  echo "Загружаем файл: $file"
  if ! upload_json=$(curl -s -X POST "$API_URL/document/upload" \
        -H "Authorization: Bearer ${API_TOKEN}" \
        -F "file=@$file" \
        --fail-with-body 2>&1); then
    echo "Ошибка при загрузке файла: $upload_json" >&2
    exit 1
  fi

  # Проверяем валидность JSON ответа
  if ! echo "$upload_json" | jq -e . >/dev/null 2>&1; then
    echo "Ошибка: невалидный JSON от сервера" >&2
    echo "Ответ сервера: $upload_json" >&2
    exit 1
  fi

  # Извлекаем location загруженного документа
  location=$(echo "$upload_json" | jq -r '.documents[0].location')

  if [ -z "$location" ] || [ "$location" = "null" ]; then
    echo "Ошибка: поле location не найдено в ответе" >&2
    echo "JSON ответ: $upload_json" >&2
    exit 1
  fi

  # Добавляем embedding в workspace
  echo "Добавляем embedding: $location в workspace: $workplace"
  curl -s -X POST "$API_URL/workspace/$workplace/update-embeddings" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${API_TOKEN}" \
    -d "{\"adds\": [\"$location\"]}" > /dev/null 2>&1

  echo "=== Файл $file успешно обработан ==="
done
