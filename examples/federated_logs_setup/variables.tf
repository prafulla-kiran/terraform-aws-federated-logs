variable "sqs_queue_arn" {
  description = "ARN of the SQS queue from the data_processing module. Pass this when deploying the setup module separately from data_processing."
  type        = string
}
