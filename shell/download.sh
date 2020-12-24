exists() {
  if command -v $1 >/dev/null 2>&1
  then
    return 0
  else
    return 1
  fi
}

unable_to_retrieve_package() {
  echo "Unable to retrieve a valid package!"
  if test "x$download_url" != "x"; then
    echo "Download URL: $download_url"
  fi
  if test "x$stderr_results" != "x"; then
    echo "\nDEBUG OUTPUT FOLLOWS:\n$stderr_results"
  fi
  exit 1
}

capture_tmp_stderr() {
  # spool up /tmp/stderr from all the commands we called
  if test -f "$tmp_dir/stderr"; then
    output=`cat $tmp_dir/stderr`
    stderr_results="${stderr_results}\nSTDERR from $1:\n\n$output\n"
    rm $tmp_dir/stderr
  fi
}

# do_wget URL FILENAME
do_wget() {
  echo "trying wget..."
  wget --user-agent="User-Agent: mixlib-install/3.12.1" -O "$2" "$1" 2>$tmp_dir/stderr
  rc=$?
  # check for 404
  grep "ERROR 404" $tmp_dir/stderr 2>&1 >/dev/null
  if test $? -eq 0; then
    echo "ERROR 404"
  fi

  # check for bad return status or empty output
  if test $rc -ne 0 || test ! -s "$2"; then
    capture_tmp_stderr "wget"
    return 1
  fi

  return 0
}

# do_curl URL FILENAME
do_curl() {
  echo "trying curl..."
  curl -A "User-Agent: mixlib-install/3.12.1" --retry 5 -sL -D $tmp_dir/stderr "$1" > "$2"
  rc=$?
  # check for 404
  grep "404 Not Found" $tmp_dir/stderr 2>&1 >/dev/null
  if test $? -eq 0; then
    echo "ERROR 404"
  fi

  # check for bad return status or empty output
  if test $rc -ne 0 || test ! -s "$2"; then
    capture_tmp_stderr "curl"
    return 1
  fi

  return 0
}

# do_fetch URL FILENAME
do_fetch() {
  echo "trying fetch..."
  fetch --user-agent="User-Agent: mixlib-install/3.12.1" -o "$2" "$1" 2>$tmp_dir/stderr
  # check for bad return status
  test $? -ne 0 && return 1
  return 0
}

# do_perl URL FILENAME
do_perl() {
  echo "trying perl..."
  perl -e 'use LWP::Simple; getprint($ARGV[0]);' "$1" > "$2" 2>$tmp_dir/stderr
  rc=$?
  # check for 404
  grep "404 Not Found" $tmp_dir/stderr 2>&1 >/dev/null
  if test $? -eq 0; then
    echo "ERROR 404"
  fi

  # check for bad return status or empty output
  if test $rc -ne 0 || test ! -s "$2"; then
    capture_tmp_stderr "perl"
    return 1
  fi

  return 0
}

# do_python URL FILENAME
do_python() {
  echo "trying python..."
  python -c "import sys,urllib2; sys.stdout.write(urllib2.urlopen(urllib2.Request(sys.argv[1], headers={ 'User-Agent': 'mixlib-install/3.12.1' })).read())" "$1" > "$2" 2>$tmp_dir/stderr
  rc=$?
  # check for 404
  grep "HTTP Error 404" $tmp_dir/stderr 2>&1 >/dev/null
  if test $? -eq 0; then
    echo "ERROR 404"
  fi

  # check for bad return status or empty output
  if test $rc -ne 0 || test ! -s "$2"; then
    capture_tmp_stderr "python"
    return 1
  fi
  return 0
}

# do_download URL FILENAME
do_download() {
  echo "downloading $1"
  echo "  to file $2"

  url=`echo $1`
  if test "x$platform" = "xsolaris2"; then
    if test "x$platform_version" = "x5.9" -o "x$platform_version" = "x5.10"; then
      # solaris 9 lacks openssl, solaris 10 lacks recent enough credentials - your base O/S is completely insecure, please upgrade
      url=`echo $url | sed -e 's/https/http/'`
    fi
  fi

  # we try all of these until we get success.
  # perl, in particular may be present but LWP::Simple may not be installed

  if exists wget; then
    do_wget $url $2 && return 0
  fi

  if exists curl; then
    do_curl $url $2 && return 0
  fi

  if exists fetch; then
    do_fetch $url $2 && return 0
  fi

  if exists perl; then
    do_perl $url $2 && return 0
  fi

  if exists python; then
    do_python $url $2 && return 0
  fi

  unable_to_retrieve_package
}