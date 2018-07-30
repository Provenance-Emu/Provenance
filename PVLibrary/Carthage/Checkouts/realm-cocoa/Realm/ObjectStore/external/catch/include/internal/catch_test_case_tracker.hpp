/*
 *  Created by Phil Nash on 23/7/2013
 *  Copyright 2013 Two Blue Cubes Ltd. All rights reserved.
 *
 *  Distributed under the Boost Software License, Version 1.0. (See accompanying
 *  file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
 */
#ifndef TWOBLUECUBES_CATCH_TEST_CASE_TRACKER_HPP_INCLUDED
#define TWOBLUECUBES_CATCH_TEST_CASE_TRACKER_HPP_INCLUDED

#include "catch_compiler_capabilities.h"
#include "catch_ptr.hpp"

#include <algorithm>
#include <string>
#include <assert.h>
#include <vector>
#include <stdexcept>

CATCH_INTERNAL_SUPPRESS_ETD_WARNINGS

namespace Catch {
namespace TestCaseTracking {

    struct NameAndLocation {
        std::string name;
        SourceLineInfo location;

        NameAndLocation( std::string const& _name, SourceLineInfo const& _location )
        :   name( _name ),
            location( _location )
        {}
    };

    struct ITracker : SharedImpl<> {
        virtual ~ITracker();

        // static queries
        virtual NameAndLocation const& nameAndLocation() const = 0;

        // dynamic queries
        virtual bool isComplete() const = 0; // Successfully completed or failed
        virtual bool isSuccessfullyCompleted() const = 0;
        virtual bool isOpen() const = 0; // Started but not complete
        virtual bool hasChildren() const = 0;

        virtual ITracker& parent() = 0;

        // actions
        virtual void close() = 0; // Successfully complete
        virtual void fail() = 0;
        virtual void markAsNeedingAnotherRun() = 0;

        virtual void addChild( Ptr<ITracker> const& child ) = 0;
        virtual ITracker* findChild( NameAndLocation const& nameAndLocation ) = 0;
        virtual void openChild() = 0;

        // Debug/ checking
        virtual bool isSectionTracker() const = 0;
        virtual bool isIndexTracker() const = 0;
    };

    class  TrackerContext {

        enum RunState {
            NotStarted,
            Executing,
            CompletedCycle
        };

        Ptr<ITracker> m_rootTracker;
        ITracker* m_currentTracker;
        RunState m_runState;

    public:

        static TrackerContext& instance() {
            static TrackerContext s_instance;
            return s_instance;
        }

        TrackerContext()
        :   m_currentTracker( CATCH_NULL ),
            m_runState( NotStarted )
        {}


        ITracker& startRun();

        void endRun() {
            m_rootTracker.reset();
            m_currentTracker = CATCH_NULL;
            m_runState = NotStarted;
        }

        void startCycle() {
            m_currentTracker = m_rootTracker.get();
            m_runState = Executing;
        }
        void completeCycle() {
            m_runState = CompletedCycle;
        }

        bool completedCycle() const {
            return m_runState == CompletedCycle;
        }
        ITracker& currentTracker() {
            return *m_currentTracker;
        }
        void setCurrentTracker( ITracker* tracker ) {
            m_currentTracker = tracker;
        }
    };

    class TrackerBase : public ITracker {
    protected:
        enum CycleState {
            NotStarted,
            Executing,
            ExecutingChildren,
            NeedsAnotherRun,
            CompletedSuccessfully,
            Failed
        };
        class TrackerHasName {
            NameAndLocation m_nameAndLocation;
        public:
            TrackerHasName( NameAndLocation const& nameAndLocation ) : m_nameAndLocation( nameAndLocation ) {}
            bool operator ()( Ptr<ITracker> const& tracker ) {
                return
                    tracker->nameAndLocation().name == m_nameAndLocation.name &&
                    tracker->nameAndLocation().location == m_nameAndLocation.location;
            }
        };
        typedef std::vector<Ptr<ITracker> > Children;
        NameAndLocation m_nameAndLocation;
        TrackerContext& m_ctx;
        ITracker* m_parent;
        Children m_children;
        CycleState m_runState;
    public:
        TrackerBase( NameAndLocation const& nameAndLocation, TrackerContext& ctx, ITracker* parent )
        :   m_nameAndLocation( nameAndLocation ),
            m_ctx( ctx ),
            m_parent( parent ),
            m_runState( NotStarted )
        {}
        virtual ~TrackerBase();

        virtual NameAndLocation const& nameAndLocation() const CATCH_OVERRIDE {
            return m_nameAndLocation;
        }
        virtual bool isComplete() const CATCH_OVERRIDE {
            return m_runState == CompletedSuccessfully || m_runState == Failed;
        }
        virtual bool isSuccessfullyCompleted() const CATCH_OVERRIDE {
            return m_runState == CompletedSuccessfully;
        }
        virtual bool isOpen() const CATCH_OVERRIDE {
            return m_runState != NotStarted && !isComplete();
        }
        virtual bool hasChildren() const CATCH_OVERRIDE {
            return !m_children.empty();
        }


        virtual void addChild( Ptr<ITracker> const& child ) CATCH_OVERRIDE {
            m_children.push_back( child );
        }

        virtual ITracker* findChild( NameAndLocation const& nameAndLocation ) CATCH_OVERRIDE {
            Children::const_iterator it = std::find_if( m_children.begin(), m_children.end(), TrackerHasName( nameAndLocation ) );
            return( it != m_children.end() )
                ? it->get()
                : CATCH_NULL;
        }
        virtual ITracker& parent() CATCH_OVERRIDE {
            assert( m_parent ); // Should always be non-null except for root
            return *m_parent;
        }

        virtual void openChild() CATCH_OVERRIDE {
            if( m_runState != ExecutingChildren ) {
                m_runState = ExecutingChildren;
                if( m_parent )
                    m_parent->openChild();
            }
        }

        virtual bool isSectionTracker() const CATCH_OVERRIDE { return false; }
        virtual bool isIndexTracker() const CATCH_OVERRIDE { return false; }

        void open() {
            m_runState = Executing;
            moveToThis();
            if( m_parent )
                m_parent->openChild();
        }

        virtual void close() CATCH_OVERRIDE {

            // Close any still open children (e.g. generators)
            while( &m_ctx.currentTracker() != this )
                m_ctx.currentTracker().close();

            switch( m_runState ) {
                case NotStarted:
                case CompletedSuccessfully:
                case Failed:
                    throw std::logic_error( "Illogical state" );

                case NeedsAnotherRun:
                    break;;

                case Executing:
                    m_runState = CompletedSuccessfully;
                    break;
                case ExecutingChildren:
                    if( m_children.empty() || m_children.back()->isComplete() )
                        m_runState = CompletedSuccessfully;
                    break;

                default:
                    throw std::logic_error( "Unexpected state" );
            }
            moveToParent();
            m_ctx.completeCycle();
        }
        virtual void fail() CATCH_OVERRIDE {
            m_runState = Failed;
            if( m_parent )
                m_parent->markAsNeedingAnotherRun();
            moveToParent();
            m_ctx.completeCycle();
        }
        virtual void markAsNeedingAnotherRun() CATCH_OVERRIDE {
            m_runState = NeedsAnotherRun;
        }
    private:
        void moveToParent() {
            assert( m_parent );
            m_ctx.setCurrentTracker( m_parent );
        }
        void moveToThis() {
            m_ctx.setCurrentTracker( this );
        }
    };

    class SectionTracker : public TrackerBase {
        std::vector<std::string> m_filters;
    public:
        SectionTracker( NameAndLocation const& nameAndLocation, TrackerContext& ctx, ITracker* parent )
        :   TrackerBase( nameAndLocation, ctx, parent )
        {
            if( parent ) {
                while( !parent->isSectionTracker() )
                    parent = &parent->parent();

                SectionTracker& parentSection = static_cast<SectionTracker&>( *parent );
                addNextFilters( parentSection.m_filters );
            }
        }
        virtual ~SectionTracker();

        virtual bool isSectionTracker() const CATCH_OVERRIDE { return true; }

        static SectionTracker& acquire( TrackerContext& ctx, NameAndLocation const& nameAndLocation ) {
            SectionTracker* section = CATCH_NULL;

            ITracker& currentTracker = ctx.currentTracker();
            if( ITracker* childTracker = currentTracker.findChild( nameAndLocation ) ) {
                assert( childTracker );
                assert( childTracker->isSectionTracker() );
                section = static_cast<SectionTracker*>( childTracker );
            }
            else {
                section = new SectionTracker( nameAndLocation, ctx, &currentTracker );
                currentTracker.addChild( section );
            }
            if( !ctx.completedCycle() )
                section->tryOpen();
            return *section;
        }

        void tryOpen() {
            if( !isComplete() && (m_filters.empty() || m_filters[0].empty() ||  m_filters[0] == m_nameAndLocation.name ) )
                open();
        }

        void addInitialFilters( std::vector<std::string> const& filters ) {
            if( !filters.empty() ) {
                m_filters.push_back(""); // Root - should never be consulted
                m_filters.push_back(""); // Test Case - not a section filter
                m_filters.insert( m_filters.end(), filters.begin(), filters.end() );
            }
        }
        void addNextFilters( std::vector<std::string> const& filters ) {
            if( filters.size() > 1 )
                m_filters.insert( m_filters.end(), ++filters.begin(), filters.end() );
        }
    };

    class IndexTracker : public TrackerBase {
        int m_size;
        int m_index;
    public:
        IndexTracker( NameAndLocation const& nameAndLocation, TrackerContext& ctx, ITracker* parent, int size )
        :   TrackerBase( nameAndLocation, ctx, parent ),
            m_size( size ),
            m_index( -1 )
        {}
        virtual ~IndexTracker();

        virtual bool isIndexTracker() const CATCH_OVERRIDE { return true; }

        static IndexTracker& acquire( TrackerContext& ctx, NameAndLocation const& nameAndLocation, int size ) {
            IndexTracker* tracker = CATCH_NULL;

            ITracker& currentTracker = ctx.currentTracker();
            if( ITracker* childTracker = currentTracker.findChild( nameAndLocation ) ) {
                assert( childTracker );
                assert( childTracker->isIndexTracker() );
                tracker = static_cast<IndexTracker*>( childTracker );
            }
            else {
                tracker = new IndexTracker( nameAndLocation, ctx, &currentTracker, size );
                currentTracker.addChild( tracker );
            }

            if( !ctx.completedCycle() && !tracker->isComplete() ) {
                if( tracker->m_runState != ExecutingChildren && tracker->m_runState != NeedsAnotherRun )
                    tracker->moveNext();
                tracker->open();
            }

            return *tracker;
        }

        int index() const { return m_index; }

        void moveNext() {
            m_index++;
            m_children.clear();
        }

        virtual void close() CATCH_OVERRIDE {
            TrackerBase::close();
            if( m_runState == CompletedSuccessfully && m_index < m_size-1 )
                m_runState = Executing;
        }
    };

    inline ITracker& TrackerContext::startRun() {
        m_rootTracker = new SectionTracker( NameAndLocation( "{root}", CATCH_INTERNAL_LINEINFO ), *this, CATCH_NULL );
        m_currentTracker = CATCH_NULL;
        m_runState = Executing;
        return *m_rootTracker;
    }

} // namespace TestCaseTracking

using TestCaseTracking::ITracker;
using TestCaseTracking::TrackerContext;
using TestCaseTracking::SectionTracker;
using TestCaseTracking::IndexTracker;

} // namespace Catch

CATCH_INTERNAL_UNSUPPRESS_ETD_WARNINGS

#endif // TWOBLUECUBES_CATCH_TEST_CASE_TRACKER_HPP_INCLUDED
