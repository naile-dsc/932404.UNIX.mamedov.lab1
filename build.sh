#!/bin/sh

if [ "$#" -ne 1 ]; then
    echo "Ошибка: необходимо указать один исходный файл" >&2
    echo "Использование: $0 <исходный_файл>" >&2
    exit 1
fi

SOURCE=$1

if [ ! -f "$SOURCE" ]; then
    echo "Ошибка: файл '$SOURCE' не найден" >&2
    exit 2
fi

OUTPUT=$(sed -n 's|^[[:space:]]*//[[:space:]]*Output:[[:space:]]*||p' "$SOURCE" | head -n 1)

if [ -z "$OUTPUT" ]; then
    echo "Ошибка: не найден комментарий '// Output: имя_файла'" >&2
    exit 3
fi

case "$OUTPUT" in
    */*|.|..)
        echo "Ошибка: после 'Output:' должно быть указано только имя файла" >&2
        exit 4
        ;;
esac

WORK_DIR=

cleanup() {
    result=$?
    trap - 0 HUP INT QUIT PIPE TERM
    if [ -n "$WORK_DIR" ] && [ -d "$WORK_DIR" ]; then
        rm -rf -- "$WORK_DIR"
    fi
    exit "$result"
}

trap cleanup 0 HUP INT QUIT PIPE TERM

WORK_DIR=$(mktemp -d) || {
    echo "Ошибка: не удалось создать временный каталог" >&2
    exit 5
}

SOURCE_DIR=$(cd "$(dirname "$SOURCE")" && pwd) || {
    echo "Ошибка: не удалось определить каталог исходного файла" >&2
    exit 6
}
SOURCE_NAME=$(basename "$SOURCE")

if ! cp "$SOURCE" "$WORK_DIR/$SOURCE_NAME"; then
    echo "Ошибка: не удалось скопировать исходный файл во временный каталог" >&2
    exit 7
fi

cd "$WORK_DIR" || {
    echo "Ошибка: не удалось перейти во временный каталог" >&2
    exit 8
}

case "$SOURCE_NAME" in
    *.c)
        echo "Сборка программы на C..."
        cc -Wall -Wextra -pedantic -O2 -o "$OUTPUT" "$SOURCE_NAME" 2>build.log
        ;;
    *.cpp|*.cxx|*.cc)
        echo "Сборка программы на C++..."
        c++ -Wall -Wextra -pedantic -O2 -o "$OUTPUT" "$SOURCE_NAME" 2>build.log
        ;;
    *)
        echo "Ошибка: поддерживаются только файлы C и C++" >&2
        exit 9
        ;;
esac

BUILD_RESULT=$?

if [ "$BUILD_RESULT" -ne 0 ]; then
    echo "Ошибка: компиляция завершилась с кодом $BUILD_RESULT" >&2
    cat build.log >&2
    exit 10
fi

if [ ! -f "$OUTPUT" ]; then
    echo "Ошибка: компилятор не создал файл '$OUTPUT'" >&2
    exit 11
fi

if ! cp "$OUTPUT" "$SOURCE_DIR/$OUTPUT"; then
    echo "Ошибка: не удалось скопировать '$OUTPUT' рядом с исходным файлом" >&2
    exit 12
fi

echo "Успешно: создан файл '$SOURCE_DIR/$OUTPUT'"