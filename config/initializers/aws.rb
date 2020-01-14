access_key_id = ENV.fetch('AWS_ACCESS_KEY_ID', 'minioadmin')
secret_access_key = ENV.fetch('AWS_SECRET_ACCESS_KEY', 'minioadmin')
bucket_name = ENV.fetch('S3_BUCKET_NAME', 'glowfic-dev')
config = {
  region: 'us-east-1',
  credentials: Aws::Credentials.new(access_key_id, secret_access_key),
}

if ENV.key?('MINIO_ENDPOINT')
  config[:endpoint] = ENV['MINIO_ENDPOINT']
  config[:force_path_style] = true
  Aws.config.update(config)

  client = Aws::S3::Client.new
  begin
    client.head_bucket(bucket: bucket_name)
  rescue StandardError => e
    puts "creating bucket #{bucket_name}..."
    client.create_bucket(acl: 'public-read', bucket: bucket_name)
  end
else
  Aws.config.update(config)
end

S3_BUCKET = Aws::S3::Resource.new.bucket(bucket_name)

Aws::Rails.add_action_mailer_delivery_method(:aws_ses)
