ls ~/libra/language/stdlib/modules/*.move | xargs ~/libra/target/release/move-build -f $1 -s $2 -d $3 $4
