#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { ClickstreamEtlStack } from '../lib/clickstream-etl-stack';

const app = new cdk.App();

new ClickstreamEtlStack(app, 'ClickstreamEtlStack', {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION || 'us-east-1',
  },
  description: 'Serverless ETL pipeline for e-commerce clickstream data processing',
});

app.synth();

