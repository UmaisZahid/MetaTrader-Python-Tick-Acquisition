//+------------------------------------------------------------------+
//|                                      Copyright 2019, Umais Zahid |
//|                                                         umais.me |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019, Umais Zahid"
#property version   "0.0.1"
//+------------------------------------------------------------------+
//| Include                                                          |
//+------------------------------------------------------------------+
#include <Zmq/Zmq.mqh>
//+------------------------------------------------------------------+
//| Properties                                                       |
//+------------------------------------------------------------------+
extern string ZEROMQ_PROTOCOL = "tcp"; 
extern string HOSTNAME = "*";
extern int PUSH_PORT = 32768;
extern int PULL_PORT = 32769;
extern int PUB_PORT = 32770;
extern int MILLISECOND_TIMER = 1;
