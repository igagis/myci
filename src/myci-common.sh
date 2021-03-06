#!/bin/bash

function error {
    local message=$1
    source ${script_dir}myci-error.sh "$message"
}

# Creates a version for given package on Bintray
# Usage:
#     createVersionOnBintray <repo-owner> <repo-name> <package-name> <version-name>
function createVersionOnBintray {
	local res=$(curl -o bintray.log -s --write-out "%{http_code}" -u$MYCI_BINTRAY_USERNAME:$MYCI_BINTRAY_API_KEY -H"Content-Type:application/json" -X POST -d"{\"name\":\"$4\",\"desc\":\"\"}" https://api.bintray.com/packages/$1/$2/$3/versions);
    [ -z "$res" ] && source myci-error.sh "curl failed while creating version on Bintray";
    echo '' >> bintray.log # to add a newline to the log
    # If response code was 409 then package version already exists, this is not an error case.
    if [ $res -ne 409 ]; then
	    [ $res -ne 201 ] && cat bintray.log && myci-error.sh "Creating version $4 on Bintray for package '$3' failed, HTTP code = $res.";
        echo "Version '$4' for package '$3' created on Bintray successfully."
    fi
	return 0;
}

# Creates a package on Bintray.
# Usage:
#     createPackageOnBintray <repo-owner> <repo-name> <package-name>
function createPackageOnBintray {
	local res=$(curl -o bintray.log -s --write-out "%{http_code}" -u$MYCI_BINTRAY_USERNAME:$MYCI_BINTRAY_API_KEY -H"Content-Type:application/json" -X POST -d"{\"name\":\"$3\",\"desc\":\"\", \"licenses\":[\"MIT\"], \"vcs_url\":\"http://github.com\"}" https://api.bintray.com/packages/$1/$2);
    [ -z "$res" ] && source myci-error.sh "curl failed while creating package on Bintray";
    echo '' >> bintray.log # to add a newline to the log
    # If response code was 409 then package already exists, this is not an error case.
    if [ $res -ne 409 ]; then
	    [ $res -ne 201 ] && cat bintray.log && myci-error.sh "Creating package '$3' failed, HTTP code = $res.";
        echo "Package '$3' created on Bintray."
    fi
	return 0;
}

# Uploads a file to Bintray debian repo.
# Usage:
#     uploadFileToDebianBintray <file-to-upload> <repo-owner> <repo-name> <package-name> <version-name> <distribution> <component> <arch>
function uploadFileToDebianBintray {
	local res=$(curl -o bintray.log -s --write-out "%{http_code}" -u$MYCI_BINTRAY_USERNAME:$MYCI_BINTRAY_API_KEY -T $1 -H"X-Bintray-Package:$4" -H"X-Bintray-Version:$5" -H"X-Bintray-Debian-Distribution:$6" -H"X-Bintray-Debian-Component:$7" -H"X-Bintray-Debian-Architecture:$8" -H"X-Bintray-Override:1" -H"X-Bintray-Publish:1" https://api.bintray.com/content/$2/$3/dists/$6/$7/binary-$8/);
    [ -z "$res" ] && source myci-error.sh "curl failed while uploading to Debian repo on Bintray";
    echo '' >> bintray.log # to add a newline to the log
	[ $res -ne 201 ] && cat bintray.log && myci-error.sh "uploading file '$1' to Bintray package '$4' version $5 failed, HTTP code = $res";
    echo "File '$1' uploaded to Bintray package '$4' version '$5'."
	return 0;
}

# Uploads a file to Bintray generic repo.
# Usage:
#     uploadFileToGenericBintray <file-to-upload> <repo-owner> <repo-name> <repo-path> <package-name> <version>
function uploadFileToGenericBintray {
	local res=$(curl -o /dev/null -s --write-out "%{http_code}" -u$MYCI_BINTRAY_USERNAME:$MYCI_BINTRAY_API_KEY -T $1 -H"X-Bintray-Package:$5" -H"X-Bintray-Version:$6" -H"X-Bintray-Override:1" -H"X-Bintray-Publish:1" https://api.bintray.com/content/$2/$3/$4/);
	[ -z "$res" ] && source myci-error.sh "curl failed while uploading file to Generic repo on Bintray";
	[ $res -ne 201 ] && myci-error.sh "uploading file '$1' to Bintray package '$5' version $6 failed, HTTP code = $res";
	echo "File '$1' uploaded to Bintray package '$5' version '$6'."
	return 0;
}

# Delete file from Bintray.
# Usage:
#     deleteFileFromBintray <file-to-delete> <repo-owner> <repo-name> <repo-path>
function deleteFileFromBintray {
	local res=$(curl -o /dev/null -s --write-out "%{http_code}" -u$MYCI_BINTRAY_USERNAME:$MYCI_BINTRAY_API_KEY -X DELETE https://api.bintray.com/content/$2/$3/$4/$1);
    [ -z "$res" ] && source myci-error.sh "curl failed while deleting file from Bintray";
	[ $res -ne 200 ] && myci-warning.sh "deleting file '$1' from Bintray failed, HTTP code = $res";
	return 0;
}

# Get package name from filename of form "myfile-1.3.0.suffix".
# Usage:
#     package_from_package_version_filename <filename>
function package_from_package_version_filename {
    echo "$1" | sed -n -e's/^\(.*\)-[0-9]\+\.[0-9]\+\.[0-9]\+\..*/\1/p';
    return 0;
}

# Get version from filename of form "myfile-1.3.0.suffix".
# Usage:
#     package_name_from_package_version_filename <filename>
function version_from_package_version_filename {
    echo "$1" | sed -n -e"s/^.*-\([0-9]\+\.[0-9]\+\.[0-9]\+\)\..*/\1/p";
    return 0;
}

# Download file from remote server via HTTP.
# Usage:
#     http_download_file <username>:<password> <url> <destination-local-filename>
# Return:
#     http status code in func_result global variable
function http_download_file {
	local creds=$1
	local url=$2
	local out_filename=$3

	local res=$(curl --user $creds --silent --location --write-out "%{http_code}" $url -o $out_filename)

	func_result=$res

	if [ $res -ne 200 ]; then
		echo "failed: could not download file from $url, HTTP response code: $res"
	fi

	return 0
}

# Upload file to remote server via HTTP.
# Usage:
#     upload_file <username>:<password> <destination-url> <local-filename>
function http_upload_file {
	local credentials=$1
	local url=$2
	local file=$3

	local md5=$(md5sum $file | awk -F" " {'print $1'})
	local sha1=$(sha1sum $file | awk -F" " {'print $1'})

	local res=$(curl -o curl.log -s --write-out "%{http_code}" \
			--user $credentials \
			--request PUT \
			--upload-file $file \
			--header "X-Checksum-Md5:$md5" \
			--header "X-Checksum-Sha1:$sha1" \
			$url \
		);

    [ -z "$res" ] && source myci-error.sh "curl failed while uploading file using PUT method";
    echo '' >> curl.log # to add a newline to the log
	# HTTP status code 201 = created
	[ $res -ne 201 ] && cat curl.log && myci-error.sh "uploading file '$file' failed, HTTP code = $res";
    echo "file '$file' uploaded"
	return 0;
}

# Delete file from remote server via HTTP.
# Usage:
#     http_delete_file <username>:<password> <file-url-to-delete>
function http_delete_file {
	local creds=$1
	local url=$2

	local res=$(curl -o /dev/null -s --write-out "%{http_code}" \
			--user $creds \
			--request DELETE \
			$url \
		);

    [ -z "$res" ] && source myci-error.sh "curl failed while deleting file '$url'";
	[ $res -ne 200 ] && myci-warning.sh "deleting file '$url' failed, HTTP code = $res";
	return 0;
}

function parse_deb_file_name {
	local file_name=$1

    func_res=($(echo $file_name | sed -E -e 's/^([^_]*)_([^_]*)_([^_]*).deb$/\1 \2 \3/g'))

    [[ ${#func_res[@]} == 3 ]] || error "malformed debian package name format: $file_name"
}

function is_in {
    local str=$1
    local strings=$2

    for s in $strings; do
        if [ "$s" == "$str" ]; then
            echo "true"
            return
        fi
    done
}

function make_curl_req {
    local method=$1
    shift
    local url=$1
    shift
    local expected_http_code=$1
    shift

    local data_arg=
    
    case $method in
        POST)
            local content_type=$1
            shift
            local data=("$@")
            case $content_type in
                json)
                    data_arg="--data"
                    local content_type_header="Content-Type: application/json"
                    ;;
                form)
                    data_arg="--form"
                    local content_type_header="Content-Type: multipart/form-data"
                    ;;
                *)
                    error "unknown content type: $content_type"
            esac
            ;;
    esac

    local tmpfile=$(mktemp)

    # delete temporary file on exit or signal caught
    trap "rm -f $tmpfile" 0 2 3 9 15
    
    local curl_cmd=(curl --location --silent $trusted --output $tmpfile \
            --write-out "%{http_code} %{ssl_verify_result}" \
            --request $method \
            $url)

    if [ ! -z "$MYCI_CREDENTIALS" ]; then
        curl_cmd+=(--user "$MYCI_CREDENTIALS")
    fi

    if [ ! -z "$data_arg" ]; then
        curl_cmd+=(--header "$content_type_header")
        for i in "${data[@]}"; do
            curl_cmd+=($data_arg "$i")
        done
    fi

    # echo "curl_cmd ="; printf '%s\n' "${curl_cmd[@]}"

    local curl_res=($("${curl_cmd[@]}" || true));
    func_res=$(cat $tmpfile)

    # echo "curl_res[0] = ${curl_res[0]}"

    if [ -z "$trusted" ] && [ ${curl_res[1]} -ne 0 ]; then
        error "SSL verification failed, ssl_verify_result = ${curl_res[1]}, func_res = $func_res";
    fi

    if [ ${curl_res[0]} -ne $expected_http_code ]; then
        error "request failed, HTTP code = ${curl_res[0]} (expected $expected_http_code), func_res = $func_res"
    fi
}
