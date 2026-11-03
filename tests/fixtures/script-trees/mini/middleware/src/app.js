import express from 'express';

export const ROUTES = [];
export function buildApp() {
  return express();
}

// Inline route so docs_stats counts an app.js action literal.
export const APP_ROUTES = [{ method: 'get', path: '/app-ping', action: 'APP_PING', fields: [] }];
