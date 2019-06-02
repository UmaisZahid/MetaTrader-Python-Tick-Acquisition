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
extern string t1 = "--- ZeroMQ Parameters ---";
extern string PROJECT_NAME = "AutoTrader";
extern string ZEROMQ_PROTOCOL = "tcp"; 
extern string HOSTNAME = "*";
extern int PUSH_PORT = 32768;
extern int PULL_PORT = 32769;
extern int PUB_PORT = 32770;
extern int MILLISECOND_TIMER = 1;
extern int SUB_TICK_WINDOW = 30;
extern int HIGH_WATER_MARK = 1;
extern bool PUBLISH_MARKET_DATA = true;
extern int NUM_OF_TICKS = 30;


extern string t1 = "--- Trading Parameters ---";
extern float MINIMUM_LOT = 0.01;
extern double MAXIMUM_LOT = 0.02;
extern bool DMA_MODE = true;
extern int MAX_SLIPPAGE = 3;

// String array of symbols being published
string Publish_Symbols[1] = {
   "GBPUSD"
};

// Integer storing current messages ID
int MessageID;

// CREATE ZeroMQ Context
Context context(PROJECT_NAME);

// CREATE ZMQ_PUSH SOCKET
Socket pushSocket(context, ZMQ_PUSH);

// CREATE ZMQ_PULL SOCKET
Socket pullSocket(context, ZMQ_PULL);

// CREATE ZMQ_PUB SOCKET
Socket pubSocket(context, ZMQ_PUB);

int OnInit()
  {
//---
   EventSetMillisecondTimer(MILLISECOND_TIMER);     // Set Millisecond Timer to get client socket input
   
   context.setBlocky(false); // Kinda useless since it sets linger time to 0 for all sockets but we've done that already explicitly
   
   // Send responses to PULL_PORT that client is listening on.
   Print("[PUSH] Binding MT4 Server to Socket on Port " + IntegerToString(PULL_PORT) + "..");
   pushSocket.bind(StringFormat("%s://%s:%d", ZEROMQ_PROTOCOL, HOSTNAME, PULL_PORT));
   pushSocket.setSendHighWaterMark(HIGH_WATER_MARK); // Sets maximum message queue before blocking/timeout
   pushSocket.setLinger(0);
   
   // Receive commands from PUSH_PORT that client is sending to.
   Print("[PULL] Binding MT4 Server to Socket on Port " + IntegerToString(PUSH_PORT) + "..");   
   pullSocket.bind(StringFormat("%s://%s:%d", ZEROMQ_PROTOCOL, HOSTNAME, PUSH_PORT));
   pullSocket.setReceiveHighWaterMark(HIGH_WATER_MARK);
   pullSocket.setLinger(0);
   
   if (PUBLISH_MARKET_DATA == true)
   {
      // Send new market data to PUB_PORT that client is subscribed to.
      Print("[PUB] Binding MT4 Server to Socket on Port " + IntegerToString(PUB_PORT) + "..");
      pubSocket.bind(StringFormat("%s://%s:%d", ZEROMQ_PROTOCOL, HOSTNAME, PUB_PORT));
   }
   
//---
   return(INIT_SUCCEEDED);
  }
  

//+------------------------------------------------------------------+
//| Expert tick function                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   /*
      Use this OnTick() function to send market data to subscribed client.
   */
   // Initialise message and tick variables, get current time
   string returnMsg;
   Print("Tick received");
   createPrototypeMessage(returnMsg, "Data:Symbol:Time,Bid,Ask,Last,Vol,Flag"); 
   MqlTick last_tick;
   
   
   if(!IsStopped() && PUBLISH_MARKET_DATA == true){
      returnMsg = returnMsg + "'Data': {";
      
      // Append each symbols tick data to the message in the form of SymbolName:DATADICT.
      for(int s = 0; s < ArraySize(Publish_Symbols); s++){
         returnMsg = returnMsg + "'" + Publish_Symbols[s] + "': ";
         addSymbolTicksToMessage(returnMsg, Publish_Symbols[s], NUM_OF_TICKS);
         if (s != (ArraySize(Publish_Symbols)-1)){
            returnMsg = returnMsg + ", ";  
         }
      }
      
      returnMsg = returnMsg + "}}"; // Once for data dict and once for total message dict
      ZmqMsg reply(returnMsg);
      pubSocket.send(reply, true); // The boolean is "nowait" parameter. Presumable this means that it doesn't block until it can send
      Print(returnMsg);
   }
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
//---
    
   Print("[PUSH] Unbinding MT4 Server from Socket on Port " + IntegerToString(PULL_PORT) + "..");
   pushSocket.unbind(StringFormat("%s://%s:%d", ZEROMQ_PROTOCOL, HOSTNAME, PULL_PORT));
   
   Print("[PULL] Unbinding MT4 Server from Socket on Port " + IntegerToString(PUSH_PORT) + "..");
   pullSocket.unbind(StringFormat("%s://%s:%d", ZEROMQ_PROTOCOL, HOSTNAME, PUSH_PORT));
   
   if (PUBLISH_MARKET_DATA == true)
   {
      Print("[PUB] Unbinding MT4 Server from Socket on Port " + IntegerToString(PUB_PORT) + "..");
      pubSocket.unbind(StringFormat("%s://%s:%d", ZEROMQ_PROTOCOL, HOSTNAME, PUB_PORT));
   }
   
   // Shutdown ZeroMQ Context
   context.shutdown();
   context.destroy(0);
   
   EventKillTimer();
}



//+---------------------------------------------------------------------------+
//| Creates prototype message filling in msgid, msgtype and msgsrc parameters |
//+---------------------------------------------------------------------------+ 
void createPrototypeMessage(string &msg, string msgType, int msgID = -1){
   msg = "{'MsgID': " + msgID + ", ";
   msg = msg + "'MsgSrc': 'MT4', ";
   msg = msg + "'MsgType': '" + msgType + "', ";
}

//+---------------------------------------------------------------------------+
//|  Appends a particular symbols tick data to an outgoing message            |
//+---------------------------------------------------------------------------+ 
void addSymbolTicksToMessage(string &msg, string symbol, int noOfTicks, datetime time = 0){
   // Assume message is already in state of 
   // { ....
   // 'Payload':{'SYMBOL':}
   // 
   
   
   if (time != 0){time = (ulong)time * 1000;} 
   msg = msg + "{";
   Print((ulong)time);
   MqlTick ticks_array[];
   ArrayResize(ticks_array, noOfTicks);
   int ticksCopied = CopyTicks(symbol, ticks_array, COPY_TICKS_ALL, time, noOfTicks);
   Print((string)ticks_array[0].bid);
   Print(ticksCopied);
   for(int x = 0; x < ticksCopied; x++){
      msg = msg + "'" + TimeToString(ticks_array[x].time,TIME_DATE|TIME_SECONDS) + "': [" + DoubleToString(ticks_array[x].bid) + ", " 
      + DoubleToString(ticks_array[x].ask) + ", " + DoubleToString(ticks_array[x].last) + ", " + DoubleToString(ticks_array[x].volume_real) + ", "
      + IntegerToString(ticks_array[x].flags);
      msg = msg + "]";
   }
   
   msg = msg + "}";
   
   // Output Message:
   // { ....
   // 'Payload':{'SYMBOL': {'TIME1':[TICKDATA],'TIME2':[TICKDATA]}}
   // 
   
}

//+---------------------------------------------------------------------------+
//|  Get MT4 Error Message                                                    |
//+---------------------------------------------------------------------------+ 
string ErrorDescription(int error_code)
  {
   string error_string;
//----
   switch(error_code)
     {
      //---- codes returned from trade server
      case 0:
      case 1:   error_string="no error";                                                  break;
      case 2:   error_string="common error";                                              break;
      case 3:   error_string="invalid trade parameters";                                  break;
      case 4:   error_string="trade server is busy";                                      break;
      case 5:   error_string="old version of the client terminal";                        break;
      case 6:   error_string="no connection with trade server";                           break;
      case 7:   error_string="not enough rights";                                         break;
      case 8:   error_string="too frequent requests";                                     break;
      case 9:   error_string="malfunctional trade operation (never returned error)";      break;
      case 64:  error_string="account disabled";                                          break;
      case 65:  error_string="invalid account";                                           break;
      case 128: error_string="trade timeout";                                             break;
      case 129: error_string="invalid price";                                             break;
      case 130: error_string="invalid stops";                                             break;
      case 131: error_string="invalid trade volume";                                      break;
      case 132: error_string="market is closed";                                          break;
      case 133: error_string="trade is disabled";                                         break;
      case 134: error_string="not enough money";                                          break;
      case 135: error_string="price changed";                                             break;
      case 136: error_string="off quotes";                                                break;
      case 137: error_string="broker is busy (never returned error)";                     break;
      case 138: error_string="requote";                                                   break;
      case 139: error_string="order is locked";                                           break;
      case 140: error_string="long positions only allowed";                               break;
      case 141: error_string="too many requests";                                         break;
      case 145: error_string="modification denied because order too close to market";     break;
      case 146: error_string="trade context is busy";                                     break;
      case 147: error_string="expirations are denied by broker";                          break;
      case 148: error_string="amount of open and pending orders has reached the limit";   break;
      case 149: error_string="hedging is prohibited";                                     break;
      case 150: error_string="prohibited by FIFO rules";                                  break;
      //---- mql4 errors
      case 4000: error_string="no error (never generated code)";                          break;
      case 4001: error_string="wrong function pointer";                                   break;
      case 4002: error_string="array index is out of range";                              break;
      case 4003: error_string="no memory for function call stack";                        break;
      case 4004: error_string="recursive stack overflow";                                 break;
      case 4005: error_string="not enough stack for parameter";                           break;
      case 4006: error_string="no memory for parameter string";                           break;
      case 4007: error_string="no memory for temp string";                                break;
      case 4008: error_string="not initialized string";                                   break;
      case 4009: error_string="not initialized string in array";                          break;
      case 4010: error_string="no memory for array\' string";                             break;
      case 4011: error_string="too long string";                                          break;
      case 4012: error_string="remainder from zero divide";                               break;
      case 4013: error_string="zero divide";                                              break;
      case 4014: error_string="unknown command";                                          break;
      case 4015: error_string="wrong jump (never generated error)";                       break;
      case 4016: error_string="not initialized array";                                    break;
      case 4017: error_string="dll calls are not allowed";                                break;
      case 4018: error_string="cannot load library";                                      break;
      case 4019: error_string="cannot call function";                                     break;
      case 4020: error_string="expert function calls are not allowed";                    break;
      case 4021: error_string="not enough memory for temp string returned from function"; break;
      case 4022: error_string="system is busy (never generated error)";                   break;
      case 4050: error_string="invalid function parameters count";                        break;
      case 4051: error_string="invalid function parameter value";                         break;
      case 4052: error_string="string function internal error";                           break;
      case 4053: error_string="some array error";                                         break;
      case 4054: error_string="incorrect series array using";                             break;
      case 4055: error_string="custom indicator error";                                   break;
      case 4056: error_string="arrays are incompatible";                                  break;
      case 4057: error_string="global variables processing error";                        break;
      case 4058: error_string="global variable not found";                                break;
      case 4059: error_string="function is not allowed in testing mode";                  break;
      case 4060: error_string="function is not confirmed";                                break;
      case 4061: error_string="send mail error";                                          break;
      case 4062: error_string="string parameter expected";                                break;
      case 4063: error_string="integer parameter expected";                               break;
      case 4064: error_string="double parameter expected";                                break;
      case 4065: error_string="array as parameter expected";                              break;
      case 4066: error_string="requested history data in update state";                   break;
      case 4073: error_string="No history data";                                          break;
      case 4099: error_string="end of file";                                              break;
      case 4100: error_string="some file error";                                          break;
      case 4101: error_string="wrong file name";                                          break;
      case 4102: error_string="too many opened files";                                    break;
      case 4103: error_string="cannot open file";                                         break;
      case 4104: error_string="incompatible access to a file";                            break;
      case 4105: error_string="no order selected";                                        break;
      case 4106: error_string="unknown symbol";                                           break;
      case 4107: error_string="invalid price parameter for trade function";               break;
      case 4108: error_string="invalid ticket";                                           break;
      case 4109: error_string="trade is not allowed in the expert properties";            break;
      case 4110: error_string="longs are not allowed in the expert properties";           break;
      case 4111: error_string="shorts are not allowed in the expert properties";          break;
      case 4200: error_string="object is already exist";                                  break;
      case 4201: error_string="unknown object property";                                  break;
      case 4202: error_string="object is not exist";                                      break;
      case 4203: error_string="unknown object type";                                      break;
      case 4204: error_string="no object name";                                           break;
      case 4205: error_string="object coordinates error";                                 break;
      case 4206: error_string="no specified subwindow";                                   break;
      default:   error_string="unknown error";
     }
//----
   return(error_string);
  }
  