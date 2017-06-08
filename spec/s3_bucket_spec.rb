require 'spec_helper'

describe 'S3 Bucket' do
  include_context :terraform

  let(:bucket_name_prefix) {RSpec.configuration.bucket_name_prefix}
  let(:topic_name_prefix) {RSpec.configuration.topic_name_prefix}
  let(:region) {RSpec.configuration.region}
  let(:deployment_identifier) {RSpec.configuration.deployment_identifier}

  subject {
    s3_bucket("#{bucket_name_prefix}-#{region}-#{deployment_identifier}")
  }

  let(:topics) do
    sns_client.list_topics.data[:topics].map do |topic|
      sns_client.get_topic_attributes(topic_arn: topic[:topic_arn])
    end
  end

  let(:topic) do
    topics.find do |topic|
      topic.attributes['DisplayName'] ==
          "#{topic_name_prefix}-#{region}-#{deployment_identifier}"
    end
  end

  context 'bucket' do
    it {should exist}

    it 'has tags' do
      tags = s3_client.get_bucket_tagging({bucket: subject.name}).to_h

      expect(tags[:tag_set]).to(
          include({key: 'Component', value: 'common'}))
      expect(tags[:tag_set]).to(
          include({key: 'Name', value: subject.name}))
      expect(tags[:tag_set]).to(
          include({key: 'DeploymentIdentifier',
                   value: deployment_identifier}))
    end
  end

  context 'event notifications' do
    it 'publishes object created and removed to the infrastructure events topic' do
      notifications = s3_client.get_bucket_notification_configuration(
          {bucket: subject.name})
      topic_configuration = notifications.topic_configurations[0]

      expect(topic_configuration.topic_arn).to(eq(topic.attributes['TopicArn']))
      expect(topic_configuration.events)
          .to(contain_exactly('s3:ObjectCreated:*', 's3:ObjectRemoved:*'))
    end
  end
end