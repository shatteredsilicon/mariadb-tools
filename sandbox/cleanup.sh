docker compose down

rm -rf tmp/*/data/*

for i in 12345 12346 12347; do
    echo "" > /tmp/$i/use
done
