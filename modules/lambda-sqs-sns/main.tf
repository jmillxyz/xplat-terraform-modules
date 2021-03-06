# # Set up SQS --------------------------------------------------------------

# SQS dead letter queue
resource "aws_sqs_queue" "dead_letter_queue" {
  name                       = "${var.stage}_${var.name}_dead_letter_queue"
  visibility_timeout_seconds = 120

  tags {
    stage   = "${var.stage}"
    service = "${var.name}"
  }
}

# The actual queue the Lambda will listen to
resource "aws_sqs_queue" "queue" {
  name           = "${var.stage}_${var.name}_queue"
  redrive_policy = "{\"deadLetterTargetArn\":\"${aws_sqs_queue.dead_letter_queue.arn}\",\"maxReceiveCount\":4}"

  visibility_timeout_seconds = "${var.visibility_timeout_seconds}"

  tags {
    stage   = "${var.stage}"
    service = "${var.name}"
  }
}

# Give permissions to SNS to send to SQS
data "aws_iam_policy_document" "sqs_write_policy" {
  statement {
    sid = "AllowLocalWrites"

    actions = [
      "sqs:SendMessage",
    ]

    resources = ["${aws_sqs_queue.queue.arn}"]

    principals {
      identifiers = ["sns.amazonaws.com"]
      type        = "Service"
    }
  }

  statement {
    sid = "AllowSNSWrites"

    actions = [
      "sqs:SendMessage",
    ]

    resources = ["${aws_sqs_queue.queue.arn}"]

    principals {
      identifiers = ["*"]
      type        = "AWS"
    }

    condition {
      test     = "ArnEquals"
      values   = ["${var.sns_arn}"]
      variable = "aws:SourceArn"
    }
  }
}

resource "aws_sqs_queue_policy" "queue_policy" {
  policy    = "${data.aws_iam_policy_document.sqs_write_policy.json}"
  queue_url = "${aws_sqs_queue.queue.id}"
}

# hook up SNS --> SQS
resource "aws_sns_topic_subscription" "sns_to_sqs" {
  topic_arn = "${var.sns_arn}"
  protocol  = "sqs"
  endpoint  = "${aws_sqs_queue.queue.arn}"
}

# hook up SQS to the Lambda
resource "aws_lambda_event_source_mapping" "event_source_mapping" {
  batch_size       = 5
  event_source_arn = "${aws_sqs_queue.queue.arn}"
  enabled          = true
  function_name    = "${var.lambda_arn}"
}
