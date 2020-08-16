//
//  RealTimeThread
//  Provenance
//
//  Created by Raf Cabezas on 10/26/2016.
//  From Apple's Tech Note 2169
//  https://developer.apple.com/library/content/technotes/tn2169/_index.html
//

void move_pthread_to_realtime_scheduling_class(pthread_t pthread);
void MakeCurrentThreadRealTime();
