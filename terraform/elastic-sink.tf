
terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "1.28.0"
    }
  }
}


provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key
  cloud_api_secret = var.confluent_cloud_api_secret
}

resource "confluent_kafka_topic" "log_shipping_raw" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  topic_name    = "log.shipping.raw"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-kafka-api-key.id
    secret = confluent_api_key.app-manager-kafka-api-key.secret
  }
}

resource "confluent_kafka_topic" "log_shipping_ecs" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  topic_name    = "log.shipping.ecs"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-kafka-api-key.id
    secret = confluent_api_key.app-manager-kafka-api-key.secret
  }
}




resource "confluent_service_account" "app-connector" {
  display_name = "app-connector"
  description  = "Service account of elasticsearch Sink Connector to consume from 'orders' topic of 'inventory' Kafka cluster"
}


resource "confluent_kafka_acl" "app-connector-describe-on-cluster" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  resource_type = "CLUSTER"
  resource_name = "kafka-cluster"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.app-connector.id}"
  host          = "*"
  operation     = "DESCRIBE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-kafka-api-key.id
    secret = confluent_api_key.app-manager-kafka-api-key.secret
  }
}

resource "confluent_kafka_acl" "app-connector-read-on-target-topic" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  resource_type = "TOPIC"
  resource_name =  "log.shipping"
  pattern_type  = "PREFIXED"
  principal     = "User:${confluent_service_account.app-connector.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-kafka-api-key.id
    secret = confluent_api_key.app-manager-kafka-api-key.secret
  }
}


resource "confluent_kafka_acl" "app-connector-create-on-target-topic" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  resource_type = "TOPIC"
  resource_name =  "log.shipping"
  pattern_type  = "PREFIXED"
  principal     = "User:${confluent_service_account.app-connector.id}"
  host          = "*"
  operation     = "CREATE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-kafka-api-key.id
    secret = confluent_api_key.app-manager-kafka-api-key.secret
  }
}


resource "confluent_kafka_acl" "app-connector-write-on-target-topic" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  resource_type = "TOPIC"
  resource_name =  "log.shipping"
  pattern_type  = "PREFIXED"
  principal     = "User:${confluent_service_account.app-connector.id}"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-kafka-api-key.id
    secret = confluent_api_key.app-manager-kafka-api-key.secret
  }
}




resource "confluent_connector" "elasticsearch-db-sink" {
  environment {
    id = confluent_environment.staging.id
  }
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }

  // Block for custom *sensitive* configuration properties that are labelled with "Type: password" under "Configuration Properties" section in the docs:
  // https://docs.confluent.io/cloud/current/connectors/cc-elasticsearch-service-sink.html#configuration-properties
  config_sensitive = {
    "connection.password" = "***REDACTED***"
  }

  // Block for custom *nonsensitive* configuration properties that are *not* labelled with "Type: password" under "Configuration Properties" section in the docs:
  // https://docs.confluent.io/cloud/current/connectors/cc-elasticsearch-service-sink.html#configuration-properties
  config_nonsensitive = {
    "connector.class"          = "ElasticsearchSink"
    "name"                     = "elasticsearch-connector"
    "kafka.auth.mode"          = "SERVICE_ACCOUNT"
    "kafka.service.account.id" = confluent_service_account.app-connector.id
    "topics"                   = confluent_kafka_topic.orders.topic_name
    "connection.url"           = "https://ec5bfac80bc14c26a77eefb6585f196c.us-west-2.aws.found.io:9243"
    "connection.username"      = "confluentuser"
    "input.data.format"        = "JSON"
    "type.name"                = "<type-name>"
    "key.ignore"               = "true"
    "schema.ignore"            = "true"
    "tasks.max"                = "1"
  }

  depends_on = [
    confluent_kafka_acl.app-connector-read-on-target-topics,
    confluent_kafka_acl.app-connector-write-on-target-topics,
    confluent_kafka_acl.app-connector-create-on-target-topics
  ]
}
