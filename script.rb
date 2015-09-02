require 'aws-sdk'
require 'optparse'

option = {}

OptionParser.new do |opt|
  opt.on('--access=VALUE', '1文字オプション 引数あり（必須）') { |v| option[:access] = v }
  opt.on('--secret=VALUE', '1文字オプション 引数あり（必須）') { |v| option[:secret] = v }
  opt.on('--stack=VALUE', '1文字オプション 引数あり（必須）') { |v| option[:stack] = v }
  opt.on('--layer=VALUE', '1文字オプション 引数あり（必須）') { |v| option[:layer] = v }
  opt.on('--app=VALUE', '1文字オプション 引数あり（必須）') { |v| option[:app] = v }
  opt.on('--instance=VALUE', '1文字オプション 引数あり（必須）') { |v| option[:instance] = v }
  opt.on('--command=VALUE', '1文字オプション 引数あり（必須）') { |v| option[:command] = v }

  opt.parse!(ARGV)
end

AWS_ACCOUNT = {
  access_key_id: option[:access],
  secret_access_key: option[:secret]
}

GAMESERVER_APPS = {
  stack_id:    option[:stack],
  layer_id:    option[:layer],
  app_id:      option[:app],
  instance_id: option[:instance]
}

# not ap-northeast-1
Aws.config[:region] = 'us-east-1'

client = Aws::OpsWorks::Client.new(
  access_key_id: AWS_ACCOUNT[:access_key_id],
  secret_access_key: AWS_ACCOUNT[:secret_access_key]
)

# always update_custom_cookbooks
resp = client.create_deployment(stack_id: GAMESERVER_APPS[:stack_id],
                                app_id: GAMESERVER_APPS[:app_id],
                                instance_ids: [GAMESERVER_APPS[:instance_id]],
                                command: {
                                  name: 'update_custom_cookbooks'
                                },
                                comment: 'update custom cookbooks')

client.wait_until(:deployment_successful,
                  deployment_ids: [resp.deployment_id]) do |w|
  w.max_attempts = 20
  w.delay = 30

  w.before_attempt do |n|
    p "update custom books #{n * w.delay}秒経過"
  end
end

resp = client.create_deployment(stack_id: GAMESERVER_APPS[:stack_id],
                                app_id: GAMESERVER_APPS[:app_id],
                                instance_ids: [GAMESERVER_APPS[:instance_id]],
                                command: {
                                  name: option[:command]
                                },
                                comment: 'running setup')

client.wait_until(:deployment_successful,
                  deployment_ids: [resp.deployment_id]) do |w|
  w.max_attempts = 20
  w.delay = 30

  w.before_attempt do |n|
    p "#{option[:command]}中 #{n * w.delay}秒経過"
  end
end

result = client.describe_deployments(deployment_ids: [resp.deployment_id])

p '-----'
p result.inspect
p result.deployments[0].status
p '-----'

exit 1 if result.deployments[0].status != 'successful'

exit 0
