
# Generates a small html snippet for an index page, from files
# in articles/
function webindex {
	cat <<EOF >index.html
<html>
	<head>
		
		<style>
		body {
			font-family: Georgia, Palatino, 'Palatino Linotype', Times, 'Times New Roman', serif;
			font-size: 12pt;
			max-width: 80ex;
		}

		p {
			margin-bottom: 1em;
		}
		.grey { color: #333333 }
		.red { color: darkred }
		</style>
	</head>
	<body>
	<h1><span class="red">raf$</span> dmesg</h1>
	<p>
	A bunch of notes in no particular order. I make no promises as to their quality or completeness, read at your own peril.
	</p>
EOF

	for filepath in $(find articles -name '*.html' | sort -r ); do
		echo "- ${filepath}"
		cat <<EOF >>index.html
		<li><a href="${filepath}">$(basename ${filepath} .html)</a></li>
EOF
	done

	cat <<EOF >>index.html
	</body>
</html>
EOF
}
