import boto3

s3 = boto3.client('s3',
                  endpoint_url="https://4d8623dbd26723876fd4cdb249982821.r2.cloudflarestorage.com",
                  aws_access_key_id="20db610abd4ccce82f8c64b182f0f7ad",
                  aws_secret_access_key="38a5f569390c4b070c4b0ea2b4d560f6152e560ace7487a669d20a194b5eb4cf")

s3.upload_file("test_new_0053.ovpn", "cloud-my-vpn", "test_new_0053.ovpn")

file_url = f"https://4d8623dbd26723876fd4cdb249982821.r2.cloudflarestorage.com/cloud-my-vpn/test_new_0053.ovpn"
print("Download link:", file_url)
          